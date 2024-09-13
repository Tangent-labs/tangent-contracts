import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterStableProcessTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }


     
    function test_revertWhen_processStableRewards_with_no_reward() external {
        address user3 = makeAddr("user processor");
        deal(user3, 100 ether);
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();
        assertEq(testCommon.crvUSD().balanceOf(user3), 0);

        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NoRewardToProcess.selector));
        market.scvUSD.processStableRewards(address(market.stakeDaoVault));
        vm.stopPrank();
    }

    function test_processStableRewards_nominal() external {
        // DO the deposit.
        uint256 depositAmount = 10_000 ether;
        address tokenIn = Addr.CURVE_CRVUSD_CRV;

        // Create user and prank
        testCommon.getUser(1, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, true, true, tokenIn);
        vm.stopPrank();

        // Create user and prank
        testCommon.getUser(2, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        vm.stopPrank();

        //let the PPS evolve.
        skip(200 days);

        // Prepare the processor user.
        address user3 = makeAddr("user processor");
        deal(user3, 100 ether);
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();
        assertEq(testCommon.crvUSD().balanceOf(user3), 0);

        // Get all info .
        (
            uint256 shareReward,
            uint256 stableReward,
            uint256 expectedProcessorFees,
            uint256 expectedDaoFees
        ) = getStableRewardToProcess(market);

        //Check the event.
        vm.expectEmit(address(splitter));
        emit LendRewardSplitter.RewardWithdraw(address(market.stakeDaoVault), shareReward);
        // Process the stable Rewards.
        vm.startPrank(user3);
        market.scvUSD.processStableRewards(address(market.stakeDaoVault));
        vm.stopPrank();

        //Check all this.
        assertEq(testCommon.crvUSD().balanceOf(user3), expectedProcessorFees, "Processor Fees Not detected");
        assertEq(
            testCommon.crvUSD().balanceOf(address(splitter)),
            stableReward - expectedProcessorFees,
            "Rewards Not detected"
        );
        assertEq(splitter.daoFeeForToken(testCommon.crvUSD()), expectedDaoFees, "DAO Fees Not detected");
    }

    function getStableRewardToProcess(
        LendRewardSplitter.MarketStruct memory market
    )
        internal
        view
        returns (uint256 shareReward, uint256 stableReward, uint256 expectedProcessorFees, uint256 expectedDaoFees)
    {
        // Count the share.
        shareReward =
            market.liquidityGauge.balanceOf(address(splitter)) -
            market.scvUSD.totalSupply() -
            market.curveLendVault.convertToAssets(market.gUSD.totalSupply());

        // Emulate the withdraw.
        stableReward = market.curveLendVault.convertToAssets(shareReward);

        // And calculation.
        uint256 PROCESSOR_FEES = market.scvUSD.processorRewardsPercentage();
        uint256 DAO_FEES = market.scvUSD.daoFeesPercentage();
        uint256 DENOMINATOR = market.scvUSD.DENOMINATOR();
        expectedProcessorFees = (stableReward * PROCESSOR_FEES) / DENOMINATOR;
        expectedDaoFees = ((stableReward - expectedProcessorFees) * DAO_FEES) / DENOMINATOR;
    }
}

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterStableClaimTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_claimStableRewards_nominal() external {
        // Get the market.
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();

        // Do the deposit.
        (address user1, ) = deposit();

        assertEq(_getlendAssetBalance(address(splitter)), 0, "No lend asset should be available on splitter");

        //let the PPS evolve.
        skip(200 days);

        // Process the stable rewards.
        vm.startPrank(user2);
        uint256 rewardToProcess = market.scvUSD.processStableRewards(address(market.stakeDaoVault));
        vm.stopPrank();

        // this part is in the balance but not distributed as reward
        uint256 daoFeesForLendAsset = splitter.daoFeeForToken(market.lendAsset);

        // No time have passed , so no reward sould be available for user , but asset should be on the splitter contract.
        assertEq(market.scvUSD.rewardPerToken(market.lendAsset), 0, "No reward should be streamed");
        assertEq(
            _getlendAssetBalance(address(splitter)),
            rewardToProcess + daoFeesForLendAsset,
            "Lend asset should be available on splitter contract"
        );

        // Go at the end of the reward period.
        skip(9 days);

        // check th claimable rewards
        CurveLendSplitterToken.EarnedData[] memory userRewards1 = market.scvUSD.claimableRewards(user1);
        assertEq(userRewards1.length, 1, "User1 should have 1 reward");
        assertEq(address(userRewards1[0].token), address(market.lendAsset), "Reward token  should be the lend asset");
        // assertEq(userRewards1[0].amount, rewardToProcess, "User1 should  get alll the reward");
        CurveLendSplitterToken.EarnedData[] memory userRewards2 = market.scvUSD.claimableRewards(user2);
        assertEq(userRewards2.length, 1, "User2 should not have rewards ");
        assertEq(userRewards2[0].amount, 0, "User2 should not have rewards ");

        //Claim
        vm.startPrank(user1);
        splitter.claimSimple(address(market.stakeDaoVault), false, user1);

        vm.stopPrank();
        uint256 userBalance = _getlendAssetBalance(user1);
        uint256 splitterBalance = _getlendAssetBalance(address(splitter));
        assertEq(
            userBalance + splitterBalance - daoFeesForLendAsset,
            rewardToProcess,
            "Balances must match the reward processed"
        );
    }

    function test_revertWhen_getRewardCalledOnToken() external {
        // Get the market.
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();

        // Do the deposit.
        (address user1, address user2) = deposit();

        vm.startPrank(user1);
        vm.expectRevert("NOT_SPLITTER");
        market.scvUSD.getReward(user1);
        vm.stopPrank();
    }

    function _getlendAssetBalance(address addy) internal returns (uint256) {
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();
        return market.lendAsset.balanceOf(addy);
    }

    function deposit() internal returns (address user1, address user2) {
        uint256 depositAmount = 10_000 ether;
        address tokenIn = Addr.CURVE_CRVUSD_CRV;
        user1 = testCommon.getUser(1, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, true, true, tokenIn);
        vm.stopPrank();
        user2 = testCommon.getUser(2, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        vm.stopPrank();
    }
}

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Addr} from "../../src/libs/Addr.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
import {ISDLiquidityGauge} from "../../src/interfaces/ISDLiquidityGauge.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurveLendVault} from "../../src/interfaces/ICurveLendVault.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";

contract LendRewardSplitterGovClaimTest is Test {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 constant DENOMINATOR = 100_000;

    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    IStakeDaoVault stakeDaoVault = IStakeDaoVault(Addr.STAKEDAO_CRV_VAULT);
    LendRewardSplitter splitter;
    ISDLiquidityGauge liquidityGauge;
    ICurveLendVault curveLendVault;
    CurveLendSplitterToken scvUSD;
    CurveLendSplitterToken gUSD;

    uint256 processorRewardsPercentage;
    uint256 daoFeesPercentage;
    bool isStableReward = false;

    address owner = makeAddr("Owner");
    address depositorOne = makeAddr("DepositorOne");
    address depositorTwo = makeAddr("DepositorTwo");
    address processor = makeAddr("Processor");

    IERC20 CRV = IERC20(Addr.TOKEN_CRV);
    IERC20 SDT = IERC20(Addr.TOKEN_SDT);

    function _deposit(address user, uint256 depositedAmount) internal {
        address tokenIn = Addr.TOKEN_CRVUSD;
        bool doDeposit = true;
        vm.stopPrank();
        vm.deal(user, 10 ether);
        deal(tokenIn, user, depositedAmount);
        vm.prank(user);
        IERC20(tokenIn).approve(address(splitter), MAX_UINT);
        vm.prank(user);
        splitter.deposit(
            address(stakeDaoVault),
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositedAmount,
            isStableReward,
            doDeposit
        );
        vm.stopPrank();
    }

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();

        splitter = testCommon.splitter();
        liquidityGauge = testCommon.liquidityGauge();
        curveLendVault = testCommon.curveLendVault();
        gUSD = testCommon.gUSD();
        scvUSD = testCommon.scvUSD();

        daoFeesPercentage = gUSD.daoFeesPercentage(); //2%
        processorRewardsPercentage = gUSD.processorRewardsPercentage(); //1%

        /// @dev Deposit
        _deposit(depositorOne, 1000 ether);
        _deposit(depositorTwo, 500 ether);
        skip(3600);
        testCommon._takesGaugeOnwershipAndSetDistributor();
    }
    function test_ClaimGovRewards() external {
        _processGovReward(false);
        skip(1 weeks);
        bool isGovRewards = true;
        uint256 shareDepositorOne = (gUSD.balanceOf(depositorOne) * 1 ether) / gUSD.totalSupply();
        uint256 shareDepositorTwo = (gUSD.balanceOf(depositorTwo) * 1 ether) / gUSD.totalSupply();

        splitter.claimSimple(address(stakeDaoVault), isGovRewards, depositorOne);
        splitter.claimSimple(address(stakeDaoVault), isGovRewards, depositorTwo);

        assertApproxEqAbs(
            (shareDepositorOne * crvClaimable) / 1 ether,
            CRV.balanceOf(address(depositorOne)),
            1_000_000 wei
        );
        assertApproxEqAbs(
            (shareDepositorOne * sdtClaimable) / 1 ether,
            SDT.balanceOf(address(depositorOne)),
            1_000_000 wei
        );
        assertApproxEqAbs(
            (shareDepositorTwo * crvClaimable) / 1 ether,
            CRV.balanceOf(address(depositorTwo)),
            1_000_000 wei
        );
        assertApproxEqAbs(
            (shareDepositorTwo * sdtClaimable) / 1 ether,
            SDT.balanceOf(address(depositorTwo)),
            1_000_000 wei
        );
    }

    function test_RevertWhen_ClaimGovRewardsWithoutLeftRewards() external {
        _processGovReward(false);
        skip(1 weeks);
        bool isGovRewards = true;
        splitter.claimSimple(address(stakeDaoVault), isGovRewards, depositorOne);
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        splitter.claimSimple(address(stakeDaoVault), isGovRewards, depositorOne);
    }

    function test_RevertWhen_ClaimGovRewardsOnGUSD() external {
        _processGovReward(false);
        skip(1 weeks);
        vm.expectRevert(bytes("NOT_SPLITTER"));
        gUSD.getReward(depositorOne);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    uint256 sdtClaimable;
    uint256 sdtProcessorRewards;
    uint256 sdtDaoFees;
    uint256 crvClaimable;
    uint256 crvProcessorRewards;
    uint256 crvDaoFees;
    function _processGovReward(bool isClaimedByUser) internal {
        LendRewardSplitterTestCommon.DistributionGauge[]
            memory distributionGauges = new LendRewardSplitterTestCommon.DistributionGauge[](2);
        distributionGauges[1] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addr.TOKEN_CRV,
            amount: 100 ether
        });
        distributionGauges[0] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addr.TOKEN_SDT,
            amount: 10 ether
        });
        testCommon._distributeGaugeRewards(distributionGauges);
        skip(72000);
        //CRV
        crvClaimable = liquidityGauge.claimable_reward(address(splitter), Addr.TOKEN_CRV);
        crvProcessorRewards = (crvClaimable * processorRewardsPercentage) / DENOMINATOR;
        crvDaoFees = (crvClaimable * daoFeesPercentage) / DENOMINATOR;
        crvClaimable -= crvProcessorRewards;
        crvClaimable -= crvDaoFees;
        //SDT
        sdtClaimable = liquidityGauge.claimable_reward(address(splitter), Addr.TOKEN_SDT);
        sdtProcessorRewards = (sdtClaimable * processorRewardsPercentage) / DENOMINATOR;
        sdtDaoFees = (sdtClaimable * daoFeesPercentage) / DENOMINATOR;
        sdtClaimable -= sdtProcessorRewards;
        sdtClaimable -= sdtDaoFees;

        /// @dev claim rewards with a random user outside of the process
        if (isClaimedByUser) liquidityGauge.claim_rewards(address(splitter));

        vm.prank(processor);
        gUSD.processGovRewards();
    }
}

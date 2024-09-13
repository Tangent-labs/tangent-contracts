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
    LendRewardSplitter splitter;

    IStakeDaoVault stakeDaoVaultCrv = IStakeDaoVault(Addr.STAKEDAO_CRVUSD_CRV);
    IStakeDaoVault stakeDaoVaultWeth = IStakeDaoVault(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
    //CRV Vault
    ISDLiquidityGauge liquidityGaugeCrv;
    ICurveLendVault curveLendVaultCrv;
    CurveLendSplitterToken scvUSD_Crv;
    CurveLendSplitterToken gUSD_Crv;
    //WETH Vault (leveraged)
    ISDLiquidityGauge liquidityGaugeWeth;
    ICurveLendVault curveLendVaultWeth;
    CurveLendSplitterToken scvUSD_Weth;
    CurveLendSplitterToken gUSD_Weth;

    uint256 processorRewardsPercentage;
    uint256 daoFeesPercentage;
    bool isStableReward = false;

    address owner = makeAddr("Owner");
    address depositorOne = makeAddr("DepositorOne");
    address depositorTwo = makeAddr("DepositorTwo");
    address processor = makeAddr("Processor");

    IERC20 CRV = IERC20(Addr.TOKEN_CRV);
    IERC20 SDT = IERC20(Addr.TOKEN_SDT);

    function _createWethLeveragedMarket() internal {
        vm.prank(owner);
        splitter.createMarket(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
        liquidityGaugeWeth = market.liquidityGauge;
        curveLendVaultWeth = market.curveLendVault;
        gUSD_Weth = market.gUSD;
        scvUSD_Weth = market.scvUSD;
    }

    function _deposit(address _stakeDaoVault, address user, uint256 depositedAmount) internal {
        address tokenIn = Addr.TOKEN_CRVUSD;
        bool doDeposit = true;
        vm.stopPrank();
        vm.deal(user, 1 ether);
        deal(tokenIn, user, depositedAmount);
        vm.prank(user);
        IERC20(tokenIn).approve(address(splitter), MAX_UINT);
        vm.prank(user);
        splitter.deposit(
            _stakeDaoVault,
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
        //CRV
        liquidityGaugeCrv = testCommon.liquidityGauge();
        curveLendVaultCrv = testCommon.curveLendVault();
        gUSD_Crv = testCommon.gUSD();
        scvUSD_Crv = testCommon.scvUSD();
        //WETH Leveraged
        _createWethLeveragedMarket();

        daoFeesPercentage = gUSD_Crv.daoFeesPercentage(); //2%
        processorRewardsPercentage = gUSD_Crv.processorRewardsPercentage(); //1%

        /// @dev Deposits
        _deposit(address(stakeDaoVaultCrv), depositorOne, 1000 ether);
        _deposit(address(stakeDaoVaultCrv), depositorTwo, 500 ether);
        _deposit(address(stakeDaoVaultWeth), depositorOne, 250 ether);
        _deposit(address(stakeDaoVaultWeth), depositorTwo, 400 ether);
        skip(3600);
        testCommon._takesGaugeOnwershipAndSetDistributor(Addr.STAKEDAO_CRVUSD_CRV);
        testCommon._takesGaugeOnwershipAndSetDistributor(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
    }

    function _calculateClaimableAmounts() internal view returns (uint256, uint256, uint256, uint256) {
        uint256 shareDepositorOneCrv = (gUSD_Crv.balanceOf(depositorOne) * 1 ether) / gUSD_Crv.totalSupply();
        uint256 shareDepositorTwoCrv = (gUSD_Crv.balanceOf(depositorTwo) * 1 ether) / gUSD_Crv.totalSupply();
        uint256 shareDepositorOneWeth = (gUSD_Weth.balanceOf(depositorOne) * 1 ether) / gUSD_Weth.totalSupply();
        uint256 shareDepositorTwoWeth = (gUSD_Weth.balanceOf(depositorTwo) * 1 ether) / gUSD_Weth.totalSupply();
        uint256 totalCrvClaimedDepositorOne = (shareDepositorOneCrv * crvClaimable_Crv) /
            1 ether +
            (shareDepositorOneWeth * crvClaimable_Weth) /
            1 ether;
        uint256 totalSdtClaimedDepositorOne = (shareDepositorOneCrv * sdtClaimable_Crv) /
            1 ether +
            (shareDepositorOneWeth * sdtClaimable_Weth) /
            1 ether;
        uint256 totalCrvClaimedDepositorTwo = (shareDepositorTwoCrv * crvClaimable_Crv) /
            1 ether +
            (shareDepositorTwoWeth * crvClaimable_Weth) /
            1 ether;
        uint256 totalSdtClaimedDepositorTwo = (shareDepositorTwoCrv * sdtClaimable_Crv) /
            1 ether +
            (shareDepositorTwoWeth * sdtClaimable_Weth) /
            1 ether;

        return (
            totalCrvClaimedDepositorOne,
            totalSdtClaimedDepositorOne,
            totalCrvClaimedDepositorTwo,
            totalSdtClaimedDepositorTwo
        );
    }

    function test_ClaimSimpleGovRewards() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        (
            uint256 totalCrvClaimedDepositorOne,
            uint256 totalSdtClaimedDepositorOne,
            uint256 totalCrvClaimedDepositorTwo,
            uint256 totalSdtClaimedDepositorTwo
        ) = _calculateClaimableAmounts();
        splitter.claimSimple(address(stakeDaoVaultCrv), isGovRewards, depositorOne);
        splitter.claimSimple(address(stakeDaoVaultCrv), isGovRewards, depositorTwo);
        splitter.claimSimple(address(stakeDaoVaultWeth), isGovRewards, depositorOne);
        splitter.claimSimple(address(stakeDaoVaultWeth), isGovRewards, depositorTwo);
        assertApproxEqAbs(totalCrvClaimedDepositorOne, CRV.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorOne, SDT.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalCrvClaimedDepositorTwo, CRV.balanceOf(depositorTwo), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorTwo, SDT.balanceOf(depositorTwo), 1_000_000 wei);
    }
    function test_ClaimMultipleGovRewards() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        (
            uint256 totalCrvClaimedDepositorOne,
            uint256 totalSdtClaimedDepositorOne,
            uint256 totalCrvClaimedDepositorTwo,
            uint256 totalSdtClaimedDepositorTwo
        ) = _calculateClaimableAmounts();
        address[] memory stakeDaoVaults = new address[](2);
        stakeDaoVaults[0] = address(stakeDaoVaultCrv);
        stakeDaoVaults[1] = address(stakeDaoVaultWeth);
        splitter.claimMultiple(stakeDaoVaults, depositorOne);
        splitter.claimMultiple(stakeDaoVaults, depositorTwo);
        assertApproxEqAbs(totalCrvClaimedDepositorOne, CRV.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorOne, SDT.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalCrvClaimedDepositorTwo, CRV.balanceOf(depositorTwo), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorTwo, SDT.balanceOf(depositorTwo), 1_000_000 wei);
    }
    function test_RevertWhen_ClaimMultipleGovRewardsWithSameVaults() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        (
            uint256 totalCrvClaimedDepositorOne,
            uint256 totalSdtClaimedDepositorOne,
            uint256 totalCrvClaimedDepositorTwo,
            uint256 totalSdtClaimedDepositorTwo
        ) = _calculateClaimableAmounts();
        address[] memory stakeDaoVaults = new address[](3);
        stakeDaoVaults[0] = address(stakeDaoVaultCrv);
        stakeDaoVaults[1] = address(stakeDaoVaultWeth);
        stakeDaoVaults[2] = address(stakeDaoVaultWeth);
        vm.expectRevert(bytes("VAULT_HAS_NOTHING_TO_CLAIM"));
        splitter.claimMultiple(stakeDaoVaults, depositorOne);
    }
    function test_RevertWhen_ClaimMultipleGovRewardsWithoutVaults() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        address[] memory stakeDaoVaults;
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        splitter.claimMultiple(stakeDaoVaults, depositorOne);
    }
    function test_RevertWhen_ClaimMultipleGovRewardsWithoutLeftRewards() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        address[] memory stakeDaoVaults = new address[](2);
        stakeDaoVaults[0] = address(stakeDaoVaultCrv);
        stakeDaoVaults[1] = address(stakeDaoVaultWeth);
        splitter.claimMultiple(stakeDaoVaults, depositorOne);
        vm.expectRevert(bytes("VAULT_HAS_NOTHING_TO_CLAIM"));
        splitter.claimMultiple(stakeDaoVaults, depositorOne);
    }

    function test_RevertWhen_ClaimSimpleGovRewardsWithoutLeftRewards() external {
        _processGovRewardForCrv();
        skip(1 weeks);
        bool isGovRewards = true;
        splitter.claimSimple(address(stakeDaoVaultCrv), isGovRewards, depositorOne);
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        splitter.claimSimple(address(stakeDaoVaultCrv), isGovRewards, depositorOne);
    }

    function test_RevertWhen_ClaimSimpleGovRewardsOnGUSD() external {
        _processGovRewardForCrv();
        skip(1 weeks);
        vm.expectRevert(bytes("NOT_SPLITTER"));
        gUSD_Crv.getReward(depositorOne);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    //CRV Vault
    uint256 sdtClaimable_Crv;
    uint256 sdtProcessorRewards_Crv;
    uint256 sdtDaoFees_Crv;
    uint256 crvClaimable_Crv;
    uint256 crvProcessorRewards_Crv;
    uint256 crvDaoFees_Crv;
    //WETH Vault
    uint256 sdtClaimable_Weth;
    uint256 sdtProcessorRewards_Weth;
    uint256 sdtDaoFees_Weth;
    uint256 crvClaimable_Weth;
    uint256 crvProcessorRewards_Weth;
    uint256 crvDaoFees_Weth;

    function _processGovRewardForCrv() internal {
        ProcessedRewards memory processedRewards = _processGovReward(
            address(stakeDaoVaultCrv),
            false,
            100 ether,
            10 ether
        );
        sdtClaimable_Crv = processedRewards.sdtClaimable;
        sdtProcessorRewards_Crv = processedRewards.sdtProcessorRewards;
        sdtDaoFees_Crv = processedRewards.sdtDaoFees;
        crvClaimable_Crv = processedRewards.crvClaimable;
        crvProcessorRewards_Crv = processedRewards.crvProcessorRewards;
        crvDaoFees_Crv = processedRewards.crvDaoFees;
    }
    function _processGovRewardForWeth() internal {
        ProcessedRewards memory processedRewards = _processGovReward(
            address(stakeDaoVaultWeth),
            false,
            500 ether,
            20 ether
        );
        sdtClaimable_Weth = processedRewards.sdtClaimable;
        sdtProcessorRewards_Weth = processedRewards.sdtProcessorRewards;
        sdtDaoFees_Weth = processedRewards.sdtDaoFees;
        crvClaimable_Weth = processedRewards.crvClaimable;
        crvProcessorRewards_Weth = processedRewards.crvProcessorRewards;
        crvDaoFees_Weth = processedRewards.crvDaoFees;
    }
    struct ProcessedRewards {
        uint256 sdtClaimable;
        uint256 sdtProcessorRewards;
        uint256 sdtDaoFees;
        uint256 crvClaimable;
        uint256 crvProcessorRewards;
        uint256 crvDaoFees;
    }
    function _processGovReward(
        address stakeDaoVault,
        bool isClaimedByUser,
        uint256 amountCrv,
        uint256 amountSdt
    ) internal returns (ProcessedRewards memory) {
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(stakeDaoVault);
        LendRewardSplitterTestCommon.DistributionGauge[]
            memory distributionGauges = new LendRewardSplitterTestCommon.DistributionGauge[](2);
        distributionGauges[1] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addr.TOKEN_CRV,
            amount: amountCrv
        });
        distributionGauges[0] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addr.TOKEN_SDT,
            amount: amountSdt
        });

        testCommon._distributeGaugeRewards(stakeDaoVault, distributionGauges);
        skip(72000);
        ProcessedRewards memory processedRewards;
        //CRV
        processedRewards.crvClaimable = market.liquidityGauge.claimable_reward(address(splitter), Addr.TOKEN_CRV);
        processedRewards.crvProcessorRewards =
            (processedRewards.crvClaimable * processorRewardsPercentage) /
            DENOMINATOR;
        processedRewards.crvDaoFees = (processedRewards.crvClaimable * daoFeesPercentage) / DENOMINATOR;
        processedRewards.crvClaimable -= processedRewards.crvProcessorRewards;
        processedRewards.crvClaimable -= processedRewards.crvDaoFees;
        //SDT
        processedRewards.sdtClaimable = market.liquidityGauge.claimable_reward(address(splitter), Addr.TOKEN_SDT);
        processedRewards.sdtProcessorRewards =
            (processedRewards.sdtClaimable * processorRewardsPercentage) /
            DENOMINATOR;
        processedRewards.sdtDaoFees = (processedRewards.sdtClaimable * daoFeesPercentage) / DENOMINATOR;
        processedRewards.sdtClaimable -= processedRewards.sdtProcessorRewards;
        processedRewards.sdtClaimable -= processedRewards.sdtDaoFees;

        /// @dev claim rewards with a random user outside of the process
        if (isClaimedByUser) market.liquidityGauge.claim_rewards(address(splitter));

        vm.prank(processor);
        market.gUSD.processGovRewards();

        return processedRewards;
    }
}

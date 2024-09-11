import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";
import {ISdtLiquidityGauge} from "../../src/interfaces/externals/ISdtLiquidityGauge.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
import {ICurveLendSplitterToken} from "../../src/interfaces/internals/ICurveLendSplitterToken.sol";
import {ICommonStruct} from "../../src/interfaces/internals/ICommonStruct.sol";
import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";

contract LendRewardSplitterGovClaimTest is Test {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 constant DENOMINATOR = 100_000;

    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();
    LendRewardSplitter splitter;

    //CRV Vault
    ISdtLiquidityGauge liquidityGaugeCrv;
    ILlamaLendVault curveLendVaultCrv;
    scvUSDSdt scvUSD_Crv;
    gUSDSdt gUSD_Crv;
    //WETH Vault (leveraged)
    ISdtLiquidityGauge liquidityGaugeWeth;
    scvUSDSdt scvUSD_Weth;
    gUSDSdt gUSD_Weth;

    uint256 processorPercentageCrv;
    uint256 daoFeesPercentageCrv;

    uint256 processorPercentageCvx;
    uint256 daoFeesPercentageCvx;

    address owner = makeAddr("Owner");
    address depositorOne = makeAddr("DepositorOne");
    address depositorTwo = makeAddr("DepositorTwo");
    address processor = makeAddr("Processor");

    IERC20 constant CRV = IERC20(AddrClassicERC20.TOKEN_CRV);
    IERC20 constant CVX = IERC20(AddrClassicERC20.TOKEN_CVX);

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();

        splitter = testCommon.splitter();
        //CRV
        liquidityGaugeCrv = testCommon.liquidityGauge();
        curveLendVaultCrv = testCommon.curveLendVault();
        gUSD_Crv = testCommon.gUSDImplem();
        scvUSD_Crv = testCommon.scvUSDImplem();
        //WETH Leveraged
        _createWethLeveragedMarket();

        (processorPercentageCrv, daoFeesPercentageCrv) = gUSD_Crv.fees(0);
        (processorPercentageCvx, daoFeesPercentageCvx) = gUSD_Crv.fees(1);
        /// @dev Deposits
        _deposit(AddrLlamaLendVaults.CRVUSD_CRV, depositorOne, 1000 ether);
        _deposit(AddrLlamaLendVaults.CRVUSD_CRV, depositorTwo, 500 ether);
        _deposit(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH, depositorOne, 250 ether);
        _deposit(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH, depositorTwo, 400 ether);
        skip(3600);
        testCommon._takesGaugeOnwershipAndSetDistributor(AddrSdtGauges.CRVUSD_CRV);
        testCommon._takesGaugeOnwershipAndSetDistributor(AddrSdtGauges.CRVUSD_LEVERAGE_WETH);
    }

    function _createWethLeveragedMarket() internal {
        vm.prank(owner);
        splitter.createSdtMarket(AddrSdtVaults.CRVUSD_LEVERAGE_WETH);
        gUSD_Weth = gUSDSdt(address(splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)));
        scvUSD_Weth = scvUSDSdt(address(splitter.scvUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)));
    }

    function _deposit(ILlamaLendVault _llamaLendVault, address user, uint256 depositedAmount) internal {
        address tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        bool doDeposit = true;
        vm.stopPrank();
        vm.deal(user, 1 ether);
        deal(tokenIn, user, depositedAmount);
        vm.startPrank(user);
        IERC20(tokenIn).approve(address(splitter), MAX_UINT);
        splitter.depositSdt(_llamaLendVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositedAmount, false, doDeposit);
        vm.stopPrank();
    }

    function _calculateClaimableAmounts() internal view returns (uint256, uint256, uint256, uint256) {
        uint256 shareDepositorOneCrv = (gUSD_Crv.balanceOf(depositorOne) * 1 ether) / gUSD_Crv.totalSupply();
        uint256 shareDepositorTwoCrv = (gUSD_Crv.balanceOf(depositorTwo) * 1 ether) / gUSD_Crv.totalSupply();
        uint256 shareDepositorOneWeth = (gUSD_Weth.balanceOf(depositorOne) * 1 ether) / gUSD_Weth.totalSupply();
        uint256 shareDepositorTwoWeth = (gUSD_Weth.balanceOf(depositorTwo) * 1 ether) / gUSD_Weth.totalSupply();
        uint256 totalCrvClaimedDepositorOne = (shareDepositorOneCrv * crvClaimable_Crv) / 1 ether + (shareDepositorOneWeth * crvClaimable_Weth) / 1 ether;
        uint256 totalSdtClaimedDepositorOne = (shareDepositorOneCrv * sdtClaimable_Crv) / 1 ether + (shareDepositorOneWeth * sdtClaimable_Weth) / 1 ether;
        uint256 totalCrvClaimedDepositorTwo = (shareDepositorTwoCrv * crvClaimable_Crv) / 1 ether + (shareDepositorTwoWeth * crvClaimable_Weth) / 1 ether;
        uint256 totalSdtClaimedDepositorTwo = (shareDepositorTwoCrv * sdtClaimable_Crv) / 1 ether + (shareDepositorTwoWeth * sdtClaimable_Weth) / 1 ether;

        return (totalCrvClaimedDepositorOne, totalSdtClaimedDepositorOne, totalCrvClaimedDepositorTwo, totalSdtClaimedDepositorTwo);
    }

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
        ProcessedRewards memory processedRewards = _processGovReward(AddrLlamaLendVaults.CRVUSD_CRV, false, 100 ether, 10 ether);
        sdtClaimable_Crv = processedRewards.cvxClaimable;
        sdtProcessorRewards_Crv = processedRewards.cvxProcessorRewards;
        sdtDaoFees_Crv = processedRewards.cvxDaoFees;
        crvClaimable_Crv = processedRewards.crvClaimable;
        crvProcessorRewards_Crv = processedRewards.crvProcessorRewards;
        crvDaoFees_Crv = processedRewards.crvDaoFees;
    }

    function _processGovRewardForWeth() internal {
        ProcessedRewards memory processedRewards = _processGovReward(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH, false, 500 ether, 20 ether);
        sdtClaimable_Weth = processedRewards.cvxClaimable;
        sdtProcessorRewards_Weth = processedRewards.cvxProcessorRewards;
        sdtDaoFees_Weth = processedRewards.cvxDaoFees;
        crvClaimable_Weth = processedRewards.crvClaimable;
        crvProcessorRewards_Weth = processedRewards.crvProcessorRewards;
        crvDaoFees_Weth = processedRewards.crvDaoFees;
    }

    struct ProcessedRewards {
        uint256 cvxClaimable;
        uint256 cvxProcessorRewards;
        uint256 cvxDaoFees;
        uint256 crvClaimable;
        uint256 crvProcessorRewards;
        uint256 crvDaoFees;
    }

    function _processGovReward(
        ILlamaLendVault llamaLendVault,
        bool isClaimedByUser,
        uint256 amountCrv,
        uint256 amountCvx
    ) internal returns (ProcessedRewards memory) {
        ICommonStruct.TokenAmount[] memory distributionGauges = new ICommonStruct.TokenAmount[](2);
        distributionGauges[1] = ICommonStruct.TokenAmount({token: CRV, amount: amountCrv});
        distributionGauges[0] = ICommonStruct.TokenAmount({token: CVX, amount: amountCvx});

        testCommon._distributeGaugeRewards(splitter.sdtGaugePerLlamaVault(llamaLendVault), distributionGauges);
        skip(72000);
        ProcessedRewards memory processedRewards;
        //CRV
        processedRewards.crvClaimable = splitter.sdtGaugePerLlamaVault(llamaLendVault).claimable_reward(address(splitter), address(CRV));
        processedRewards.crvProcessorRewards = (processedRewards.crvClaimable * processorPercentageCrv) / DENOMINATOR;
        processedRewards.crvDaoFees = (processedRewards.crvClaimable * daoFeesPercentageCrv) / DENOMINATOR;
        processedRewards.crvClaimable -= processedRewards.crvProcessorRewards;
        processedRewards.crvClaimable -= processedRewards.crvDaoFees;
        //CVX
        processedRewards.cvxClaimable = splitter.sdtGaugePerLlamaVault(llamaLendVault).claimable_reward(address(splitter), address(CVX));
        processedRewards.cvxProcessorRewards = (processedRewards.cvxClaimable * processorPercentageCvx) / DENOMINATOR;
        processedRewards.cvxDaoFees = (processedRewards.cvxClaimable * daoFeesPercentageCvx) / DENOMINATOR;
        processedRewards.cvxClaimable -= processedRewards.cvxProcessorRewards;
        processedRewards.cvxClaimable -= processedRewards.cvxDaoFees;

        /// @dev claim rewards with a random user outside of the process
        if (isClaimedByUser) splitter.sdtGaugePerLlamaVault(llamaLendVault).claim_rewards(address(splitter));

        vm.prank(processor);
        gUSDSdt(address(splitter.gUSDSdtPerLlamaVault(llamaLendVault))).processRewards();

        return processedRewards;
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
        splitter.claimSimple(address(gUSD_Crv), depositorOne);
        splitter.claimSimple(address(gUSD_Crv), depositorTwo);
        splitter.claimSimple(address(gUSD_Weth), depositorOne);
        splitter.claimSimple(address(gUSD_Weth), depositorTwo);
        assertApproxEqAbs(totalCrvClaimedDepositorOne, CRV.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorOne, CVX.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalCrvClaimedDepositorTwo, CRV.balanceOf(depositorTwo), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorTwo, CVX.balanceOf(depositorTwo), 1_000_000 wei);
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
        address[] memory lendSplitterTokens = new address[](2);
        lendSplitterTokens[0] = address(gUSD_Crv);
        lendSplitterTokens[1] = address(gUSD_Weth);
        splitter.claimMultiple(lendSplitterTokens, depositorOne, 2);
        splitter.claimMultiple(lendSplitterTokens, depositorTwo, 2);
        assertApproxEqAbs(totalCrvClaimedDepositorOne, CRV.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorOne, CVX.balanceOf(depositorOne), 1_000_000 wei);
        assertApproxEqAbs(totalCrvClaimedDepositorTwo, CRV.balanceOf(depositorTwo), 1_000_000 wei);
        assertApproxEqAbs(totalSdtClaimedDepositorTwo, CVX.balanceOf(depositorTwo), 1_000_000 wei);
    }

    function test_RevertWhen_ClaimMultipleGovRewardsWithSameVaults() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        bool isGovRewards = true;
        (uint256 totalCrvClaimedDepositorOne, uint256 totalSdtClaimedDepositorOne, uint256 totalCrvClaimedDepositorTwo, ) = _calculateClaimableAmounts();
        address[] memory lendSplitterTokens = new address[](3);
        lendSplitterTokens[0] = address(gUSD_Crv);
        lendSplitterTokens[1] = address(gUSD_Weth);
        lendSplitterTokens[2] = address(gUSD_Weth);

        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.NoRewardsToClaimFromContract.selector, address(gUSD_Weth)));
        splitter.claimMultiple(lendSplitterTokens, depositorOne, 2);
    }

    function test_RevertWhen_ClaimMultipleGovRewardsWithoutVaults() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);
        address[] memory lendSplitterTokens;

        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.NoRewardToMultiClaim.selector));
        splitter.claimMultiple(lendSplitterTokens, depositorOne, 2);
    }

    function test_RevertWhen_ClaimMultipleGovRewardsWithoutLeftRewards() external {
        _processGovRewardForCrv();
        _processGovRewardForWeth();
        skip(1 weeks);

        address[] memory lendSplitterTokens = new address[](2);
        lendSplitterTokens[0] = address(gUSD_Crv);
        lendSplitterTokens[1] = address(gUSD_Weth);
        splitter.claimMultiple(lendSplitterTokens, depositorOne, 2);
        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.NoRewardsToClaimFromContract.selector, address(gUSD_Crv)));
        splitter.claimMultiple(lendSplitterTokens, depositorOne, 2);
    }

    function test_RevertWhen_ClaimSimpleGovRewardsWithoutLeftRewards() external {
        _processGovRewardForCrv();
        skip(1 weeks);
        bool isGovRewards = true;

        splitter.claimSimple(address(gUSD_Crv), depositorOne);

        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.NoRewardToSimpleClaim.selector));
        splitter.claimSimple(address(gUSD_Crv), depositorOne);
    }

    function test_RevertWhen_ClaimSimpleGovRewardsOnGUSD() external {
        _processGovRewardForCrv();
        skip(1 weeks);

        vm.prank(depositorOne);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NotLendRewardSplitter.selector, depositorOne));
        gUSD_Crv.getAndUpdateRewards(depositorOne);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
contract AccessControlMarkets is MarketDeploymentContext {
    ConvexCrvLPMarket marketCrv;
    ConvexCrvLPMarket marketCrvWithoutConvex;
    ConvexFxnLPMarket marketFxn;
    BasicERC20Market marketBasicERC20;

    function setUp() public {
        marketCrv = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        marketCrvWithoutConvex = deployConvexCurveLPMarket(AddrCurveStableLP.USDT_crvUSD);
        marketFxn = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        marketBasicERC20 = deployBasicERC20Market(AddrPTPendle.sUSDe_31_07_25);

        vm.startPrank(usr1);
    }
    function test_setCollatOracle_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setCollatOracle(IPriceOracle(usr2));
    }

    function test_setMaxLTV_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setMaxLTV(100);
    }

    function test_setLiquidationThreshold_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setLiquidationThreshold(100);
    }

    function test_setLiquidationFee_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setLiquidationFee(100);
    }

    function test_setMaxMarketDebt_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setMaxMarketDebt(100);
    }

    function test_setMinimumLoan_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCrv.setMinimumLoan(100);
    }

    function test_initialize_alreadyInit_market() external {
        GlobalMarketInitParams memory _marketConstants = GlobalMarketInitParams(address(0), usg, controlTower, irCalculator, rewardAccumulator, zappingProxy);
        MarketInit memory _marketInit = MarketInit(AddrClassicERC20.CRV, IPriceOracle(address(0)), 0, 0, 0, 0, 0, new IERC20[](0), "");
        vm.expectRevert(abi.encodeWithSelector(MarketCore.AlreadyInitialized.selector));
        marketCrv.initialize(_marketConstants, _marketInit, 0);
    }

    function test_claimUnderlyingRewards_on_ConvexCrvMarket_fails_when_caller_not_rewardAccumulator() external {
        IERC20[] memory rTokens = new IERC20[](1);
        rTokens[0] = AddrClassicERC20.CRV;

        vm.expectRevert(abi.encodeWithSelector(MarketExternalActions.NotRewardAccumulator.selector));
        marketCrv.claimUnderlyingRewards(rTokens);
    }

    function test_claimUnderlyingRewards_on_ConvexFxnvMarket_fails_when_caller_not_rewardAccumulator() external {
        IERC20[] memory rTokens = new IERC20[](1);
        rTokens[0] = AddrClassicERC20.CRV;

        vm.expectRevert(abi.encodeWithSelector(MarketExternalActions.NotRewardAccumulator.selector));
        marketFxn.claimUnderlyingRewards(rTokens);
    }

    function test_claimUnderlyingRewards_on_BasicERC20Market_fails_when_caller_not_rewardAccumulator() external {
        IERC20[] memory rTokens = new IERC20[](1);
        rTokens[0] = AddrClassicERC20.CRV;

        vm.expectRevert(abi.encodeWithSelector(MarketExternalActions.NotRewardAccumulator.selector));
        marketBasicERC20.claimUnderlyingRewards(rTokens);
    }

    function test_setDepositPaused_success() external {
        vm.stopPrank();
        vm.startPrank(pauser);
        marketCrv.setPause(PauseSettings.PauseEnum.DepositPaused, 1);
        (uint64 isDepositPaused, , ) = marketCrv.getPausedSettings();
        assertEq(isDepositPaused, 1);
    }

    function test_setBorrowPaused_success() external {
        vm.stopPrank();
        vm.startPrank(pauser);
        marketCrv.setPause(PauseSettings.PauseEnum.BorrowPaused, 1);
        (, uint64 isBorrowPaused, ) = marketCrv.getPausedSettings();
        assertEq(isBorrowPaused, 1);
    }

    function test_setLeveragePaused_success() external {
        vm.stopPrank();
        vm.startPrank(pauser);
        marketCrv.setPause(PauseSettings.PauseEnum.LeveragePaused, 1);
        (, , uint64 isLeveragePaused) = marketCrv.getPausedSettings();
        assertEq(isLeveragePaused, 1);
    }

    function test_setDepositPaused_fails_as_not_pauser() external {
        vm.expectRevert(abi.encodeWithSelector(PauseSettings.CallerNotPauser.selector));
        marketCrv.setPause(PauseSettings.PauseEnum.DepositPaused, 1);
    }

    function test_setBorrowPaused_fails_as_not_pauser() external {
        vm.expectRevert(abi.encodeWithSelector(PauseSettings.CallerNotPauser.selector));
        marketCrv.setPause(PauseSettings.PauseEnum.BorrowPaused, 1);
    }

    function test_setLeveragePaused_fails_as_not_pauser() external {
        vm.expectRevert(abi.encodeWithSelector(PauseSettings.CallerNotPauser.selector));
        marketCrv.setPause(PauseSettings.PauseEnum.LeveragePaused, 1);
    }
}

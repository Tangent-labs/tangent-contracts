// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
contract AccessControlMarkets is MarketDeploymentContext {
    ConvexCrvLPMarket market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
        vm.startPrank(usr1);
    }
    function test_setCollatOracle_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setCollatOracle(IPriceOracle(usr2));
    }

    function test_setMaxLTV_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setMaxLTV(100);
    }

    function test_setLiquidationThreshold_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setLiquidationThreshold(100);
    }

    function test_setLiquidationFee_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setLiquidationFee(100);
    }

    function test_setMaxMarketDebt_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setMaxMarketDebt(100);
    }

    function test_setMinimumLoan_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setMinimumLoan(100);
    }

    function test_setSocFee_fails_as_not_owner() external {
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        market.setSociabilizationFee(100);
    }

    function test_initialize_alreadyInit_market() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.AlreadyInitialized.selector));

        GlobalMarketInitParams memory _marketConstants = GlobalMarketInitParams(address(0), tgUSD, controlTower, irCalculator, rewardAccumulator, zappingProxy);
        MarketInit memory _marketInit = MarketInit(AddrClassicERC20.CRV, IPriceOracle(address(0)), 0, 0, 0, 0, 0);

        market.initialize(_marketConstants, _marketInit, ICvxRewardToken(address(0)), 0, 0);
    }
}

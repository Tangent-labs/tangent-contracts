// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract CreateCurveGaugeMarket is MarketDeploymentContext {
    RCParams public rcParams;
    IRParams public irParams;
    MarketInit public marketInit;

    function setUp() external {
        IERC20[] memory rewardTokens = new IERC20[](1);
        rewardTokens[0] = AddrClassicERC20.PYUSD;

        marketInit = MarketInit({
            name: "",
            collatToken: AddrCurveStableLP.PYUSD_USDC,
            collatOracle: IPriceOracle(address(0)),
            maxLTV: 0,
            liquidationThreshold: 95_000,
            liquidationFee: 0,
            maxMarketDebt: 0,
            rewardTokens: rewardTokens,
            minimumLoan: 0
        });
        irParams = IRParams({isHEC: true, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 995_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
        rcParams = RCParams({harvestFeePercentage: 1_000, startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995_000, endCutPrice: 900_000});
    }

    function test_createCurveGaugeMarket_success() external {
        vm.startPrank(owner);
        address market = marketCreator.createCurveGaugeMarket(marketInit, AddrCurveGauge.PYUSD_USDC, irParams, rcParams);

        assertTrue(usg.isMinter(market));
        assertTrue(usg.isBurner(market));
        assertTrue(rewardAccumulator.isMarket(market));
        assertEq(irCalculator.debtIndexes(market), RAY);
        assertTrue(address(CurveGaugeMarket(market).receiptToken()) != address(0));
        assertEq(address(rewardAccumulator.rewardTokens(market, 0)), address(AddrClassicERC20.PYUSD));
    }

    function test_createCurveGaugeMarket_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createCurveGaugeMarket(marketInit, AddrCurveGauge.PYUSD_USDC, irParams, rcParams);
    }

    function test_createCurveGaugeMarket_fails_as_wrong_gauge() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(CurveGaugeMarket.WrongGaugeToken.selector));
        marketCreator.createCurveGaugeMarket(marketInit, AddrCurveGauge.RLUSD_USDC, irParams, rcParams);
    }
}

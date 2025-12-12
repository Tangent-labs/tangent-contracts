// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract CreateConvexCrvMarket is MarketDeploymentContext {
    RCParams public rcParams;
    IRParams public irParams;
    MarketInit public marketInit;

    function setUp() external {
        IERC20[] memory rewardTokens = new IERC20[](2);
        rewardTokens[0] = AddrClassicERC20.CRV;
        rewardTokens[1] = AddrClassicERC20.CVX;

        marketInit = MarketInit({
            name: "",
            collatToken: AddrCurveStableLP.USDC_crvUSD,
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

    function test_createConvexCrvMarket_success() external {
        vm.startPrank(owner);
        address market = marketCreator.createConvexCrvMarket(marketInit, PidCvxCrvBooster.USDC_crvUSD_LP, irParams, rcParams);

        assertTrue(usg.isMinter(market));
        assertTrue(usg.isBurner(market));
        assertTrue(rewardAccumulator.isMarket(market));
        assertEq(irCalculator.debtIndexes(market), RAY);
        assertEq(address(ConvexCrvLPMarket(market).cvxRewardToken()), address(AddrCvxRewardTokens.USDC_crvUSD_LP));
        assertEq(address(rewardAccumulator.rewardTokens(market, 0)), address(AddrClassicERC20.CRV));
        assertEq(address(rewardAccumulator.rewardTokens(market, 1)), address(AddrClassicERC20.CVX));
    }

    function test_createConvexCrvMarket_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createConvexCrvMarket(marketInit, PidCvxCrvBooster.USDC_crvUSD_LP, irParams, rcParams);
    }

    function test_createConvexCrvMarket_fails_when_collatToken_and_lpToken_not_same() external {
        IERC20[] memory rewardTokens = new IERC20[](2);
        rewardTokens[0] = AddrClassicERC20.CRV;
        rewardTokens[1] = AddrClassicERC20.CVX;
        vm.startPrank(owner);
        marketInit = MarketInit({
            name: "",
            collatToken: AddrCurveStableLP.USDT_crvUSD,
            collatOracle: IPriceOracle(address(0)),
            maxLTV: 0,
            liquidationThreshold: 95_000,
            liquidationFee: 0,
            maxMarketDebt: 0,
            rewardTokens: rewardTokens,
            minimumLoan: 0
        });

        vm.expectRevert(abi.encodeWithSelector(ConvexCrvLPMarket.WrongPoolId.selector));
        marketCreator.createConvexCrvMarket(marketInit, PidCvxCrvBooster.USDC_crvUSD_LP, irParams, rcParams);
    }
}

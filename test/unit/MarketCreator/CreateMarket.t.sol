// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract CreateMarket is MarketDeploymentContext {
    uint256 maxLTV;
    uint256 liquidationThreshold;
    uint256 liquidationFee;
    uint256 maxMarketDebt;
    uint256 minimumLoan;

    MarketInit public marketInit =
        MarketInit({
            name: "",
            collatToken: IERC20Metadata(address(0)),
            collatOracle: IPriceOracle(address(0)),
            maxLTV: 0,
            liquidationThreshold: 0,
            liquidationFee: 0,
            maxMarketDebt: 0,
            minimumLoan: 0
        });
    IRParams public irParams = IRParams({isHEC: true, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 995_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
    RCParams public rcParams =
        RCParams({harvestFeePercentage: 1_000, startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995_000, endCutPrice: 900_000});
    function test_createConvexCrvMarket_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createConvexCrvMarket(marketInit, ICvxRewardToken(address(0)), 0, irParams, rcParams);
    }

    function test_createConvexFxnMarket_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createConvexFxnMarket(marketInit, 0, irParams, rcParams);
    }

    function test_createBasicERC20Market_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createBasicERC20Market(marketInit, irParams, rcParams);
    }

    function test_market_creation_fails_as_maxLTV_smaller_than_liquidation_threshold() external {
        vm.startPrank(owner);
        marketInit.maxLTV = 90_000;
        marketInit.liquidationThreshold = 89_000;
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationThresholdTooLow.selector));
        marketCreator.createBasicERC20Market(marketInit, irParams, rcParams);
    }

    function test_market_creation_fails_as_liquidation_threshold_more_than_100() external {
        vm.startPrank(owner);
        marketInit.liquidationThreshold = 100_000;
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationThresholdTooHigh.selector));
        marketCreator.createBasicERC20Market(marketInit, irParams, rcParams);
    }

    function test_market_creation_fails_as_liquidation_fee_more_than_15() external {
        vm.startPrank(owner);

        marketInit.maxLTV = 89_000;
        marketInit.liquidationThreshold = 90_000;

        marketInit.liquidationFee = 80_000;
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationFeeTooHigh.selector));
        marketCreator.createBasicERC20Market(marketInit, irParams, rcParams);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
contract UpdateAdminParamsMarkets is MarketDeploymentContext {
    ConvexCrvLPMarket market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
        vm.startPrank(owner);
    }
    function test_setCollatOracle_success() external {
        market.setCollatOracle(IPriceOracle(usr2));

        assertEq(address(market.collatOracle()), usr2);
    }

    function test_setMaxLTV_success() external {
        market.setMaxLTV(85_000);
        assertEq(market.maxLTV(), 85_000);
    }

    function test_setMaxLTV_fails_when_higher_than_liquidationThreshold() external {
        vm.expectRevert(abi.encodeWithSelector(Collateral.MaxLTVLowerThanLiquidationThreshold.selector));
        market.setMaxLTV(98_000);
    }

    function test_setLiquidationThreshold_success() external {
        market.setLiquidationThreshold(96_000);
        assertEq(market.liquidationThreshold(), 96_000);
    }

    function test_setLiquidationThreshold_fails_when_higher_than_100() external {
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationThresholdTooHigh.selector));
        market.setLiquidationThreshold(100_000);
    }

    function test_setLiquidationThreshold_fails_when_lower_than_maxLTV() external {
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationThresholdTooLow.selector));
        market.setLiquidationThreshold(90_000);
    }

    function test_setLiquidationFee_success() external {
        market.setLiquidationFee(10_001);
        assertEq(market.liquidationFee(), 10_001);
    }

    function test_setLiquidationFee_fails_when_higher_than_100() external {
        vm.expectRevert(abi.encodeWithSelector(Collateral.LiquidationFeeTooHigh.selector));
        market.setLiquidationFee(15_001);
    }

    function test_setMaxMarketDebt_success() external {
        market.setMaxMarketDebt(10_000_000 ether);
        assertEq(market.maxMarketDebt(), 10_000_000 ether);
    }

    function test_setMinimumLoan_success() external {
        market.setMinimumLoan(5_000 ether);
        assertEq(market.minimumLoan(), 5_000 ether);
    }

    function test_setSocFeePercentage_success() external {
        market.setSocFeePercentage(1_500);
        assertEq(market.socFeePercentage(), 1_500);
    }

    function test_setSocFeePercentage_fails_because_too_high() external {
        vm.expectRevert(abi.encodeWithSelector(Sociabilization.SocFeeTooHigh.selector));
        market.setSocFeePercentage(15_001);
    }
}

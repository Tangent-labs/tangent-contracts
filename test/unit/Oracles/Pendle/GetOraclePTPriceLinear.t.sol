// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract GetOraclePTPriceLinear is MarketDeploymentContext {
    OraclePendlePTLinearDiscount linearDiscountPTOracleExpired;
    OraclePendlePTLinearDiscount linearDiscountPTOracleNotExpired;

    function setUp() external {
        // Oracle PT sUSDE 31_07_25
        linearDiscountPTOracleExpired = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrERC4626.sUSDe], 2 * 10 ** 17, "PT sUSDe 31/07/25 Linear");
        // Oracle PT sUSDe 25_09_25
        linearDiscountPTOracleNotExpired = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_27_11_25, oracles[AddrERC4626.sUSDe], 2 * 10 ** 17, "PT sUSDe 27/11/25 Linear");
    }

    function test_estimate_PT_price_linear_expired() external {
        uint256 price = linearDiscountPTOracleExpired.latestAnswer(true);
        (, IPriceOracle oracle, , ) = linearDiscountPTOracleExpired.params();
        assertEq(price, oracle.latestAnswer(true));
    }

    function test_estimate_PT_price_linear_not_expired() external {
        uint256 price1 = linearDiscountPTOracleNotExpired.latestAnswer(true);
        uint256 maturity = AddrMarketPendle.sUSDe_27_11_25.expiry();

        (, IPriceOracle oracle, , uint256 baseDiscountPerYear) = linearDiscountPTOracleExpired.params();

        uint256 timeLeft = maturity - block.timestamp;
        uint256 discount = (timeLeft * baseDiscountPerYear) / 365 days;
        assertEq(discount, linearDiscountPTOracleNotExpired.getCurrentDiscount());
        assertEq((oracle.latestAnswer(true) * (1 ether - discount)) / 1 ether, price1);

        skip(1 weeks);

        uint256 price2 = linearDiscountPTOracleNotExpired.latestAnswer(true);

        assertGt(price2, price1);

        timeLeft = maturity - block.timestamp;
        discount = (timeLeft * baseDiscountPerYear) / 365 days;
        assertEq(discount, linearDiscountPTOracleNotExpired.getCurrentDiscount());
        assertEq((oracle.latestAnswer(true) * (1 ether - discount)) / 1 ether, price2);

        skip(14 weeks);

        assertEq(linearDiscountPTOracleNotExpired.latestAnswer(true), oracle.latestAnswer(true));
    }

    function test_create_linear_discount_contract_with_discount_more_than_100() external {
        vm.expectRevert(abi.encodeWithSelector(OraclePendlePTLinearDiscount.DiscountMoreThan100Percent.selector));
        new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrERC4626.sUSDe], 1 ether + 1, "PT sUSDe31/07/25 Linear");
    }
}

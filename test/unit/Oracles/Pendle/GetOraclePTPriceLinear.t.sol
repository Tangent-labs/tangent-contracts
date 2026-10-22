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
        uint256 price = linearDiscountPTOracleExpired.latestAnswerUpdate(true);
        IPriceOracle oracle = linearDiscountPTOracleExpired.underlyingOracle();
        IPendleSYToken sy = linearDiscountPTOracleExpired.sy();
        // 1 expired PT = 1 accounting asset (USDe), not 1 sUSDe
        assertEq(price, (oracle.latestAnswer(true) * 1 ether) / sy.exchangeRate());
    }

    function test_estimate_PT_price_linear_not_expired() external {
        uint256 price1 = linearDiscountPTOracleNotExpired.latestAnswer(true);
        uint256 maturity = AddrMarketPendle.sUSDe_27_11_25.expiry();

        IPriceOracle oracle = linearDiscountPTOracleNotExpired.underlyingOracle();
        uint256 baseDiscountPerYear = linearDiscountPTOracleNotExpired.baseDiscountPerYear();
        IPendleSYToken sy = linearDiscountPTOracleNotExpired.sy();
        uint256 assetPrice = (oracle.latestAnswer(true) * 1 ether) / sy.exchangeRate();

        uint256 timeLeft = maturity - block.timestamp;
        uint256 discount = (timeLeft * baseDiscountPerYear) / 365 days;
        assertEq(discount, linearDiscountPTOracleNotExpired.getCurrentDiscount());
        assertEq((assetPrice * (1 ether - discount)) / 1 ether, price1);

        skip(1 weeks);

        uint256 price2 = linearDiscountPTOracleNotExpired.latestAnswer(true);

        assertGt(price2, price1);

        timeLeft = maturity - block.timestamp;
        discount = (timeLeft * baseDiscountPerYear) / 365 days;
        assertEq(discount, linearDiscountPTOracleNotExpired.getCurrentDiscount());
        assetPrice = (oracle.latestAnswer(true) * 1 ether) / sy.exchangeRate();
        assertEq((assetPrice * (1 ether - discount)) / 1 ether, price2);

        skip(14 weeks);

        assertEq(linearDiscountPTOracleNotExpired.latestAnswer(true), (oracle.latestAnswer(true) * 1 ether) / sy.exchangeRate());
    }

    function test_estimate_PT_price_linear_sy_rate_drops() external {
        IPriceOracle oracle = linearDiscountPTOracleExpired.underlyingOracle();
        IPendleSYToken sy = linearDiscountPTOracleExpired.sy();
        uint256 pyIndexStored = linearDiscountPTOracleExpired.yt().pyIndexStored();

        // NAV write-down: SY rate falls 10% under the stored PY index, which never decreases
        vm.mockCall(address(sy), abi.encodeWithSelector(IPendleSYToken.exchangeRate.selector), abi.encode((pyIndexStored * 9) / 10));

        // 1 PT still redeems 1 / pyIndexStored SY, so the PT takes the loss
        assertEq(linearDiscountPTOracleExpired.latestAnswer(true), (oracle.latestAnswer(true) * 1 ether) / pyIndexStored);
    }

    function test_estimate_PT_price_linear_sy_rate_drops_then_maturity() external {
        OraclePendlePTLinearDiscount ptOracle = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_07_05_26, oracles[AddrERC4626.sUSDe], 2 * 10 ** 17, "PT sUSDe 07/05/26 Linear");
        IPriceOracle oracle = ptOracle.underlyingOracle();
        IPendleSYToken sy = ptOracle.sy();
        uint256 pyIndexStored = ptOracle.yt().pyIndexStored();
        uint256 maturity = AddrMarketPendle.sUSDe_07_05_26.expiry();
        assertLt(block.timestamp, maturity);

        // NAV write-down before maturity
        vm.mockCall(address(sy), abi.encodeWithSelector(IPendleSYToken.exchangeRate.selector), abi.encode((pyIndexStored * 9) / 10));
        uint256 assetPrice = (oracle.latestAnswer(true) * 1 ether) / pyIndexStored;
        assertEq(ptOracle.latestAnswer(true), (assetPrice * (1 ether - ptOracle.getCurrentDiscount())) / 1 ether);

        // After maturity the discount is gone, but the PT still redeems at the stored PY index
        vm.warp(maturity + 1 weeks);
        assertEq(ptOracle.getCurrentDiscount(), 0);
        assertEq(ptOracle.latestAnswer(true), (oracle.latestAnswer(true) * 1 ether) / pyIndexStored);
    }

    function test_create_linear_discount_contract_with_discount_more_than_100() external {
        vm.expectRevert(abi.encodeWithSelector(OraclePendlePTLinearDiscount.DiscountMoreThan100Percent.selector));
        new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrERC4626.sUSDe], 1 ether + 1, "PT sUSDe31/07/25 Linear");
    }

    function test_create_linear_discount_contract_with_cumulated_discount_more_than_100() external {
        // 60%/year with 2 years left => 120% discount
        vm.mockCall(address(AddrMarketPendle.sUSDe_27_11_25), abi.encodeWithSelector(IPendleMarketV3.expiry.selector), abi.encode(block.timestamp + 2 * 365 days));
        vm.expectRevert(abi.encodeWithSelector(OraclePendlePTLinearDiscount.DiscountMoreThan100Percent.selector));
        new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_27_11_25, oracles[AddrERC4626.sUSDe], 6e17, "PT sUSDe 27/11/25 Linear");
    }
}

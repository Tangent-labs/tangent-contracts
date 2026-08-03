// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import {MockChainlinkOracle} from "../../../mocks/MockChainlinkOracle.sol";
import {IPendlePYLpOracle} from "../../../../src/interfaces/externals/Pendle/IPendlePYLpOracle.sol";

/// @dev Covers the two safety properties of `OraclePendlePT`:
///        - the constructor rejects a denominator scale that does not match the market accounting asset
///          and an underlying oracle that is not 18 decimals,
///        - the price can never exceed the price of the SY it is derived from.
contract OraclePendlePTGuards is MarketDeploymentContext {
    IPendlePYLpOracle constant pendleOracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    // Market with an 18 decimals accounting asset (USDS), not expired at the fork block => scale of 18.
    IPendleMarketV3 constant MARKET_18_DEC = AddrMarketPendle.sUSDS_26_11_26;
    // Market with an 8 decimals accounting asset (cbBTC), not expired at the fork block => scale of 28.
    IPendleMarketV3 constant MARKET_8_DEC = AddrMarketPendle.mHyperBTC_30_04_26;

    uint88 constant DURATION = 900;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR CHECKS
     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_constructor_reverts_when_the_underlying_oracle_is_not_18_decimals() external {
        MockChainlinkOracle oracle8Dec = new MockChainlinkOracle(1e8, 8);

        vm.expectRevert(abi.encodeWithSelector(OraclePendlePT.InvalidUnderlyingOracleDecimals.selector));
        new OraclePendlePT(MARKET_18_DEC, oracle8Dec, DURATION, 18, "PT sUSDS / USD");
    }

    function test_constructor_reverts_when_the_scale_ignores_the_asset_decimals() external {
        // The accounting asset of that market has 8 decimals, so the rate is 1e28 based and 18 is short by 1e10.
        vm.expectRevert(abi.encodeWithSelector(OraclePendlePT.InvalidDenominatorScale.selector));
        new OraclePendlePT(MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 18, "PT mHyperBTC / USD");
    }

    function test_constructor_reverts_when_the_scale_overshoots_the_asset_decimals() external {
        // Mirror case: the asset has 18 decimals, so 28 would divide the price by an extra 1e10.
        vm.expectRevert(abi.encodeWithSelector(OraclePendlePT.InvalidDenominatorScale.selector));
        new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 28, "PT sUSDS / USD");
    }

    function test_constructor_accepts_the_scale_derived_from_the_market() external {
        OraclePendlePT oracle18Dec = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        OraclePendlePT oracle8Dec = new OraclePendlePT(MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 28, "PT mHyperBTC / USD");

        (, , , uint8 scale18Dec) = oracle18Dec.params();
        (, , , uint8 scale8Dec) = oracle8Dec.params();

        assertEq(scale18Dec, 18, "Scale of an 18 decimals asset market");
        assertEq(scale8Dec, 28, "Scale of an 8 decimals asset market");

        // Both prices are 18 decimals based, so they stay in the same order of magnitude as their SY.
        assertApproxEqRel(oracle18Dec.latestAnswer(true), oracles[AddrERC4626.sUSDS].latestAnswer(true), 0.2 ether, "PT sUSDS price magnitude");
        assertApproxEqRel(oracle8Dec.latestAnswer(true), oracles[AddrClassicERC20.WBTC].latestAnswer(true), 0.2 ether, "PT mHyperBTC price magnitude");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            PRICE CAP
     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// @dev Forces the Pendle PT/SY rate returned for `market` over `DURATION`.
    function _mockPtToSyRate(IPendleMarketV3 market, uint256 rate) internal {
        vm.mockCall(
            address(pendleOracle),
            abi.encodeWithSelector(IPendlePYLpOracle.getPtToSyRate.selector, address(market), uint32(DURATION)),
            abi.encode(rate)
        );
    }

    function test_price_is_capped_at_the_sy_price_when_the_pt_trades_above_par() external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);

        // A negative implied rate would make the PT worth more than the SY, which can not happen.
        _mockPtToSyRate(MARKET_18_DEC, 2e18);

        assertEq(ptOracle.latestAnswer(true), syPrice, "Capped at the SY price");
    }

    function test_price_is_capped_for_a_market_with_an_8_decimals_asset() external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 28, "PT mHyperBTC / USD");
        uint256 syPrice = oracles[AddrClassicERC20.WBTC].latestAnswer(true);

        _mockPtToSyRate(MARKET_8_DEC, 2e28);

        assertEq(ptOracle.latestAnswer(true), syPrice, "Capped at the SY price");
    }

    function test_price_is_capped_on_latest_answer_update() external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswerUpdate(true);

        _mockPtToSyRate(MARKET_18_DEC, type(uint128).max);

        assertEq(ptOracle.latestAnswerUpdate(true), syPrice, "Capped at the SY price");
    }

    function test_price_is_the_sy_price_when_the_pt_is_exactly_at_par() external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);

        // Boundary: at par the cap must not kick in, the price is already the SY price.
        _mockPtToSyRate(MARKET_18_DEC, 1e18);
        assertEq(ptOracle.latestAnswer(true), syPrice, "Price at par");

        // One wei above par, the cap returns the same value.
        _mockPtToSyRate(MARKET_18_DEC, 1e18 + 1);
        assertEq(ptOracle.latestAnswer(true), syPrice, "Price one wei above par");
    }

    function test_price_is_left_untouched_in_normal_conditions() external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);
        uint256 rate = pendleOracle.getPtToSyRate(address(MARKET_18_DEC), uint32(DURATION));

        // The market is not expired, so the PT is discounted and the cap is not reached.
        assertLt(rate, 1e18, "PT discounted before maturity");
        assertEq(ptOracle.latestAnswer(true), (rate * syPrice) / 1e18, "Uncapped price");
        assertLt(ptOracle.latestAnswer(true), syPrice, "Uncapped price below the SY price");
    }

    function test_price_of_an_expired_pt_is_left_untouched() external view {
        // Expired market of an accruing SY: 1 PT redeems for 1 USDe, which is worth less than 1 sUSDe.
        IPriceOracle ptOracle = oracles[AddrPTPendle.sUSDe_05_02_26];
        uint256 syPrice = oracles[AddrERC4626.sUSDe].latestAnswer(true);
        uint256 rate = pendleOracle.getPtToSyRate(address(AddrMarketPendle.sUSDe_05_02_26), uint32(DURATION));

        assertLt(rate, 1e18, "Matured PT worth less than one SY");
        assertEq(ptOracle.latestAnswer(true), (rate * syPrice) / 1e18, "Uncapped price");
        assertLt(ptOracle.latestAnswer(true), syPrice, "Uncapped price below the SY price");
    }

    function testFuzz_price_never_exceeds_the_sy_price(uint256 rate) external {
        OraclePendlePT ptOracle = new OraclePendlePT(MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "PT sUSDS / USD");
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);

        // Upper bound kept below the multiplication overflow, the Pendle rate is a small fixed point number.
        _mockPtToSyRate(MARKET_18_DEC, bound(rate, 0, 1e40));

        assertLe(ptOracle.latestAnswer(true), syPrice, "Price never above the SY price");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import {OraclePendleLP} from "../../../../src/USG/Oracles/Pendle/OraclePendleLP.sol";
import {MockChainlinkOracle} from "../../../mocks/MockChainlinkOracle.sol";
import {IPendlePYLpOracle} from "../../../../src/interfaces/externals/Pendle/IPendlePYLpOracle.sol";

/// @dev Covers `OraclePendleLP`: the constructor checks (18 decimals underlying oracle, denominator scale
///      derived from the market accounting asset) and the pricing itself, before and after maturity.
contract GetOraclePendleLPPrice is MarketDeploymentContext {
    IPendlePYLpOracle constant pendleOracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    // Not expired at the fork block, accounting asset USDS (18 decimals) => scale of 18.
    IPendleMarketV3 constant LIVE_MARKET_18_DEC = AddrMarketPendle.sUSDS_26_11_26;
    // Not expired at the fork block, accounting asset reUSD (6 decimals) => scale of 30.
    IPendleMarketV3 constant LIVE_MARKET_6_DEC = AddrMarketPendle.reUSD_10_12_26;
    // Expired at the fork block, accounting asset USDe (18 decimals) => scale of 18.
    IPendleMarketV3 constant EXPIRED_MARKET_18_DEC = AddrMarketPendle.sUSDe_05_02_26;
    // Expired at the fork block, accounting asset cbBTC (8 decimals) => scale of 28.
    IPendleMarketV3 constant EXPIRED_MARKET_8_DEC = AddrMarketPendle.mHyperBTC_30_04_26;

    uint88 constant DURATION = 900;

    OraclePendleLP liveLPOracle;
    OraclePendleLP expiredLPOracle;

    function setUp() external {
        // The SY of those markets is minted 1:1 against sUSDS / sUSDe, so their oracle prices one SY.
        liveLPOracle = new OraclePendleLP(LIVE_MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 18, "LP sUSDS 26/11/26 / USD");
        expiredLPOracle = new OraclePendleLP(EXPIRED_MARKET_18_DEC, oracles[AddrERC4626.sUSDe], DURATION, 18, "LP sUSDe 05/02/26 / USD");

        vm.label(address(liveLPOracle), "Oracle LP sUSDS_26_11_26");
        vm.label(address(expiredLPOracle), "Oracle LP sUSDe_05_02_26");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR CHECKS
     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_constructor_reverts_when_the_underlying_oracle_is_not_18_decimals() external {
        MockChainlinkOracle oracle8Dec = new MockChainlinkOracle(1e8, 8);

        vm.expectRevert(abi.encodeWithSelector(OraclePendleLP.InvalidUnderlyingOracleDecimals.selector));
        new OraclePendleLP(LIVE_MARKET_18_DEC, oracle8Dec, DURATION, 18, "LP sUSDS / USD");
    }

    function test_constructor_reverts_when_the_scale_ignores_the_asset_decimals() external {
        // cbBTC has 8 decimals, so the rate is 1e28 based and 18 is short by 1e10.
        vm.expectRevert(abi.encodeWithSelector(OraclePendleLP.InvalidDenominatorScale.selector));
        new OraclePendleLP(EXPIRED_MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 18, "LP mHyperBTC / USD");

        // reUSD has 6 decimals, so the rate is 1e30 based and 18 is short by 1e12.
        vm.expectRevert(abi.encodeWithSelector(OraclePendleLP.InvalidDenominatorScale.selector));
        new OraclePendleLP(LIVE_MARKET_6_DEC, oracles[AddrClassicERC20.USDS], DURATION, 18, "LP reUSD / USD");
    }

    function test_constructor_reverts_when_the_scale_overshoots_the_asset_decimals() external {
        // Mirror case: USDS has 18 decimals, so 28 would divide the price by an extra 1e10.
        vm.expectRevert(abi.encodeWithSelector(OraclePendleLP.InvalidDenominatorScale.selector));
        new OraclePendleLP(LIVE_MARKET_18_DEC, oracles[AddrERC4626.sUSDS], DURATION, 28, "LP sUSDS / USD");
    }

    function test_constructor_accepts_the_scale_derived_from_the_market() external {
        OraclePendleLP oracle6Dec = new OraclePendleLP(LIVE_MARKET_6_DEC, oracles[AddrClassicERC20.USDS], DURATION, 30, "LP reUSD / USD");
        OraclePendleLP oracle8Dec = new OraclePendleLP(EXPIRED_MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 28, "LP mHyperBTC / USD");

        (, , , uint8 scale6Dec) = oracle6Dec.params();
        (, , , uint8 scale8Dec) = oracle8Dec.params();
        (, , , uint8 scale18Dec) = liveLPOracle.params();

        assertEq(scale6Dec, 30, "Scale of a 6 decimals asset market");
        assertEq(scale8Dec, 28, "Scale of an 8 decimals asset market");
        assertEq(scale18Dec, 18, "Scale of an 18 decimals asset market");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PRICE BEFORE MATURITY
     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_price_before_maturity_is_the_lp_to_sy_rate_times_the_sy_price() external view {
        uint256 syPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);
        uint256 rate = pendleOracle.getLpToSyRate(address(LIVE_MARKET_18_DEC), uint32(DURATION));

        assertEq(liveLPOracle.latestAnswer(true), (rate * syPrice) / 1e18, "LP price composition");
    }

    /// @dev Cross checks the SY route used by the oracle against the asset route of the same Pendle
    ///      oracle: pricing 1 LP through `getLpToSyRate` * $ sUSDS must give the same result as
    ///      `getLpToAssetRate` * $ USDS. That validates both the scale and the choice of underlying oracle.
    function test_price_matches_the_asset_route_of_the_pendle_oracle() external view {
        uint256 assetPrice = oracles[AddrClassicERC20.USDS].latestAnswer(true);
        uint256 lpToAssetRate = pendleOracle.getLpToAssetRate(address(LIVE_MARKET_18_DEC), uint32(DURATION));

        // Only the truncations of the two routes differ, so the relative gap is bounded by 1e-6 %.
        assertApproxEqRel(liveLPOracle.latestAnswer(true), (lpToAssetRate * assetPrice) / 1e18, 1e12, "SY route against asset route");
    }

    function test_price_of_a_lp_is_above_the_price_of_one_sy() external view {
        // A LP is a share of the SY + PT reserves plus the accrued fees, it is not capped by the SY price.
        assertGt(liveLPOracle.latestAnswer(true), oracles[AddrERC4626.sUSDS].latestAnswer(true), "LP worth more than one SY");
    }

    /// @dev The scale is per market: on a BTC market the rate is 1e28 based, so dividing by 1e18 would
    ///      over value the LP by 1e10. WBTC is used as a stand in here, a real deployment needs an oracle
    ///      of the SY yield token itself.
    function test_price_of_a_market_with_a_non_18_decimals_asset_uses_its_own_scale() external {
        OraclePendleLP btcLPOracle = new OraclePendleLP(EXPIRED_MARKET_8_DEC, oracles[AddrClassicERC20.WBTC], DURATION, 28, "LP mHyperBTC / USD");

        uint256 btcPrice = oracles[AddrClassicERC20.WBTC].latestAnswer(true);
        uint256 rate = pendleOracle.getLpToSyRate(address(EXPIRED_MARKET_8_DEC), uint32(DURATION));

        assertEq(btcLPOracle.latestAnswer(true), (rate * btcPrice) / 1e28, "LP price composition");
        // One LP of that market is a small fraction of a BTC, a 1e18 scale would blow that up by 1e10.
        assertGt(btcLPOracle.latestAnswer(true), 0, "Non zero price");
        assertLt(btcLPOracle.latestAnswer(true), btcPrice / 1000, "Price in the right order of magnitude");
    }

    function test_latest_answer_update_returns_the_same_price() external {
        assertEq(liveLPOracle.latestAnswerUpdate(true), liveLPOracle.latestAnswer(true), "Update path");
        assertEq(expiredLPOracle.latestAnswerUpdate(true), expiredLPOracle.latestAnswer(true), "Update path, expired market");
    }

    /// @dev The TWAP branch reverts when the observation buffer of the market is shorter than `duration`,
    ///      even in no fail mode. The observation cardinality must be checked before deploying.
    function test_price_reverts_when_the_observation_buffer_is_too_short() external {
        OraclePendleLP shortBufferOracle = new OraclePendleLP(LIVE_MARKET_18_DEC, oracles[AddrERC4626.sUSDS], 1_000_000, 18, "LP sUSDS / USD");

        vm.expectRevert();
        shortBufferOracle.latestAnswer(true);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PRICE AFTER MATURITY
     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_price_after_maturity_is_the_lp_to_sy_rate_times_the_sy_price() external view {
        assertTrue(EXPIRED_MARKET_18_DEC.isExpired(), "Market expired");

        uint256 syPrice = oracles[AddrERC4626.sUSDe].latestAnswer(true);
        uint256 rate = pendleOracle.getLpToSyRate(address(EXPIRED_MARKET_18_DEC), uint32(DURATION));

        assertEq(expiredLPOracle.latestAnswer(true), (rate * syPrice) / 1e18, "LP price composition");
        // The LP still holds the SY + PT reserves of the market, its value does not collapse at maturity.
        assertGt(expiredLPOracle.latestAnswer(true), syPrice, "LP worth more than one SY");
    }

    /// @dev After maturity the PT leg is worth par, no TWAP is read anymore, so `duration` is ignored and
    ///      the oracle can not revert on the observation buffer.
    function test_price_after_maturity_ignores_the_duration() external {
        OraclePendleLP shortDuration = new OraclePendleLP(EXPIRED_MARKET_18_DEC, oracles[AddrERC4626.sUSDe], 0, 18, "LP sUSDe / USD");
        OraclePendleLP absurdDuration = new OraclePendleLP(EXPIRED_MARKET_18_DEC, oracles[AddrERC4626.sUSDe], 1_000_000, 18, "LP sUSDe / USD");

        uint256 price = expiredLPOracle.latestAnswer(true);

        assertEq(shortDuration.latestAnswer(true), price, "Duration of 0");
        assertEq(absurdDuration.latestAnswer(true), price, "Duration longer than the buffer");
    }

    function test_price_of_an_expired_lp_follows_its_sy() external {
        uint256 priceBefore = expiredLPOracle.latestAnswer(true);

        // The reserves of a matured market keep accruing through their SY leg.
        skip(30 days);

        assertGt(expiredLPOracle.latestAnswer(true), priceBefore, "Price follows the SY accrual");
    }
}

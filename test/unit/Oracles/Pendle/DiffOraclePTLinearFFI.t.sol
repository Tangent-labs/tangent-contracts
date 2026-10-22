// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {OraclePendlePTLinearDiscount} from "../../../../src/USG/Oracles/Pendle/OraclePendlePTLinearDiscount.sol";
import {OracleChainlinkWrapper} from "../../../../src/USG/Oracles/Token/OracleChainlinkWrapper.sol";
import {OracleERC4626} from "../../../../src/USG/Oracles/Token/OracleERC4626.sol";
import {OracleERC4626FromCurveLP} from "../../../../src/USG/Oracles/Token/OracleERC4626FromCurveLP.sol";
import {OracleCoinFromCurveLP} from "../../../../src/USG/Oracles/Token/OracleCoinFromCurveLP.sol";
import {ICurveStableSwapNG} from "../../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../../../../src/interfaces/internals/USG/IPriceOracle.sol";
import {IAggregatorV3} from "../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IPendlePYLpOracle} from "../../../../src/interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../../src/interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendleSYToken} from "../../../../src/interfaces/externals/Pendle/IPendleSYToken.sol";
import {MockChainlinkOracle} from "../../../mocks/MockChainlinkOracle.sol";

import {AddrERC4626, AddrChainlinkOracle} from "../../../../src/libs/Resources/ResourcesGlobal.sol";
import {AddrMarketPendle} from "../../../../src/libs/Resources/ResourcesPendle.sol";
import {AddrCurveStableLP} from "../../../../src/libs/Resources/ResourcesCurveLP.sol";

/// @notice Differential test of the linear discount PT oracle against the live market price:
///         - off-chain : Pendle API through ffi
///         - on-chain  : Pendle PT/asset TWAP
/// @dev    Forks the latest block so both references are taken at the same time.
contract DiffOraclePTLinearFFI is Test {
    IPendlePYLpOracle constant pendleOracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);
    uint32 constant TWAP_DURATION = 900;

    // Deepest sUSDe pool on Curve (~$60M), coin0 = DOLA, coin1 = sUSDe
    ICurveStableSwapNG constant DOLA_sUSDe = ICurveStableSwapNG(0x744793B5110f6ca9cC7CDfe1CE16677c3Eb192ef);
    // Both coins are ERC4626, coin0 = sUSDe, coin1 = sUSDS
    ICurveStableSwapNG constant sUSDe_sUSDS = ICurveStableSwapNG(0x3CEf1AFC0E8324b57293a6E7cE663781bbEFBB79);
    // Deepest reUSD pool on Curve (~$2.3M), coin0 = reUSD (oracle asset type), coin1 = sUSDe
    ICurveStableSwapNG constant reUSD_sUSDe = ICurveStableSwapNG(0x5C2ab69Eb2BF12A2f4572D178687Bd4660512972);

    // Conservative discount rate, above the ~5% implied APY of both markets
    uint96 constant BASE_DISCOUNT_PER_YEAR = 8e16;

    function setUp() external {
        vm.createSelectFork("mainnet");
    }

    function test_diff_PT_sUSDe_26_11_26() external {
        IPriceOracle usde = _chainlink(AddrChainlinkOracle.USDe);
        _diff(AddrMarketPendle.sUSDe_26_11_26, new OracleERC4626(AddrERC4626.sUSDe, usde, "sUSDe NAV / USD"), usde, BASE_DISCOUNT_PER_YEAR, "PT sUSDe 26/11/26 Linear (NAV)");
    }

    function test_diff_PT_sUSDS_26_11_26() external {
        IPriceOracle usds = _chainlink(AddrChainlinkOracle.USDS);
        _diff(AddrMarketPendle.sUSDS_26_11_26, new OracleERC4626(AddrERC4626.sUSDS, usds, "sUSDS NAV / USD"), usds, BASE_DISCOUNT_PER_YEAR, "PT sUSDS 26/11/26 Linear (NAV)");
    }

    /// @notice reUSD: SY 18 decimals, accounting asset USDC 6 decimals, PT 6 decimals.
    ///         reUSD is priced at its market rate from the deepest reUSD Curve pool (oracle asset type, coin0 = reUSD, coin1 = sUSDe).
    function test_diff_PT_reUSD_10_12_26() external {
        IPriceOracle usdc = _chainlink(AddrChainlinkOracle.USDC);
        // sUSDe at its market rate too: the reUSD/sUSDe EMA is quoted against the traded sUSDe, not its NAV
        IPriceOracle reUSDMarket = new OracleERC4626FromCurveLP(reUSD_sUSDe, 0, _sUSDeMarket(), "reUSD market / USD");

        // reUSD NAV: SY rate (raw USDC per raw reUSD) in USDC
        uint256 reUSDNAV = (usdc.latestAnswer(false) * _sy(AddrMarketPendle.reUSD_10_12_26).exchangeRate()) / 1e6;
        console.log("reUSD market price  ", reUSDMarket.latestAnswer(false));
        console.log("reUSD NAV price     ", reUSDNAV);
        console.log("  premium (bps)     ", _bps(reUSDMarket.latestAnswer(false), reUSDNAV));

        // Implied linear rate ~11.5%
        _diff(AddrMarketPendle.reUSD_10_12_26, reUSDMarket, usdc, 15e16, "PT reUSD 10/12/26 Linear (market rate)");
    }

    /// @notice USD3: ERC4626 over USDC, all 6 decimals.
    function test_diff_PT_USD3_17_12_26() external {
        IPriceOracle usdc = _chainlink(AddrChainlinkOracle.USDC);
        // Implied linear rate ~14%, the Pendle API quotes ~75 bps above the TWAP: keep the rate tight to stay within 1% of both
        _diff(AddrMarketPendle.USD3_17_12_26, new OracleERC4626(AddrERC4626.USD3, usdc, "USD3 NAV / USD"), usdc, 15e16, "PT USD3 17/12/26 Linear");
    }

    /// @notice 1 year after expiry the oracle must still price: the only Pendle call at read time is `SY.exchangeRate()`.
    ///         The SY price is mocked so a stale Chainlink feed doesn't hide the Pendle side.
    function test_PT_not_bricked_1_year_after_expiry() external {
        IPendleMarketV3[4] memory markets = [AddrMarketPendle.sUSDe_26_11_26, AddrMarketPendle.sUSDS_26_11_26, AddrMarketPendle.reUSD_10_12_26, AddrMarketPendle.USD3_17_12_26];
        MockChainlinkOracle syOracle = new MockChainlinkOracle(1.1e18, 18);

        OraclePendlePTLinearDiscount[4] memory ptOracles;
        for (uint256 i; i < 4; i++) ptOracles[i] = new OraclePendlePTLinearDiscount(markets[i], syOracle, BASE_DISCOUNT_PER_YEAR, "PT");

        vm.warp(markets[3].expiry() + 800 days);
        vm.roll(block.number + 800 days / 12);

        for (uint256 i; i < 4; i++) {
            IPendleSYToken sy = _sy(markets[i]);
            (, , uint8 assetDecimals) = sy.assetInfo();
            uint256 expected = (1.1e18 * 10 ** (18 + assetDecimals - sy.decimals())) / sy.exchangeRate();
            console.log(markets[i].expiry(), "exchangeRate", sy.exchangeRate());

            assertEq(ptOracles[i].getCurrentDiscount(), 0);
            assertEq(ptOracles[i].latestAnswer(false), expected);
            assertEq(ptOracles[i].latestAnswerUpdate(false), expected);
            // Deploying after expiry works too
            assertEq(new OraclePendlePTLinearDiscount(markets[i], syOracle, BASE_DISCOUNT_PER_YEAR, "PT").latestAnswer(false), expected);
        }
    }

    /// @notice sUSDe priced at its Curve market rate: a premium / discount to NAV flows into the PT price.
    function test_diff_PT_sUSDe_26_11_26_market_rate() external {
        IPriceOracle usde = _chainlink(AddrChainlinkOracle.USDe);
        IPriceOracle sUSDeMarkett = _sUSDeMarket();
        IPriceOracle _sUSDeNAV = new OracleERC4626(AddrERC4626.sUSDe, usde, "sUSDe NAV / USD");

        console.log("sUSDe market price  ", sUSDeMarkett.latestAnswer(false));
        console.log("sUSDe NAV price     ", _sUSDeNAV.latestAnswer(false));
        console.log("  premium (bps)     ", _bps(sUSDeMarkett.latestAnswer(false), _sUSDeNAV.latestAnswer(false)));

        _diff(AddrMarketPendle.sUSDe_26_11_26, sUSDeMarkett, usde, BASE_DISCOUNT_PER_YEAR, "PT sUSDe 26/11/26 Linear (market rate)");
    }

    /// @notice Pool where both coins are ERC4626, pricing the vault at index 0 (sUSDe) and index 1 (sUSDS).
    function test_ERC4626_market_rate_both_coins_ERC4626() external {
        IPriceOracle usde = _chainlink(AddrChainlinkOracle.USDe);
        IPriceOracle usds = _chainlink(AddrChainlinkOracle.USDS);
        IPriceOracle _sUSDeNAV = new OracleERC4626(AddrERC4626.sUSDe, usde, "sUSDe NAV / USD");
        IPriceOracle _sUSDSNAV = new OracleERC4626(AddrERC4626.sUSDS, usds, "sUSDS NAV / USD");

        // The other coin oracle prices the other vault token itself, not its asset
        IPriceOracle sUSDeMarkett = new OracleERC4626FromCurveLP(sUSDe_sUSDS, 0, _sUSDSNAV, "sUSDe market / USD");
        IPriceOracle _sUSDSMarket = new OracleERC4626FromCurveLP(sUSDe_sUSDS, 1, _sUSDeNAV, "sUSDS market / USD");

        console.log("sUSDe market vs NAV (bps)", _bps(sUSDeMarkett.latestAnswer(false), _sUSDeNAV.latestAnswer(false)));
        console.log("sUSDS market vs NAV (bps)", _bps(_sUSDSMarket.latestAnswer(false), _sUSDSNAV.latestAnswer(false)));

        // Thin pool (~$100k), only check the order of magnitude: a wrong rate / index would be off by ~12-25%
        assertApproxEqRel(sUSDeMarkett.latestAnswer(false), _sUSDeNAV.latestAnswer(false), 1e16);
        assertApproxEqRel(_sUSDSMarket.latestAnswer(false), _sUSDSNAV.latestAnswer(false), 1e16);

        // Index 0 and 1 are the inverse of each other: sUSDe/sUSDS * sUSDS/sUSDe = 1
        uint256 sUSDeInsUSDS = (sUSDeMarkett.latestAnswer(false) * 1e18) / _sUSDSNAV.latestAnswer(false);
        uint256 sUSDSInsUSDe = (_sUSDSMarket.latestAnswer(false) * 1e18) / _sUSDeNAV.latestAnswer(false);
        assertApproxEqRel((sUSDeInsUSDS * sUSDSInsUSDe) / 1e18, 1e18, 1e10);
    }

    /// @notice Older pools (only `price_oracle()`) are rejected: OracleCoinFromCurveLP covers them.
    function test_ERC4626_market_rate_reverts_on_old_pool() external {
        vm.expectRevert();
        new OracleERC4626FromCurveLP(ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E), 1, _chainlink(AddrChainlinkOracle.USDC), "crvUSD");
    }

    /// @notice NG pool with mixed decimals and no rate oracle: USDC (6) / fxUSD (18), stored_rates = [1e30, 1e18].
    function test_ERC4626_market_rate_NG_pool_mixed_decimals() external {
        ICurveStableSwapNG USDC_fxUSD = ICurveStableSwapNG(0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f);
        IPriceOracle usdc = _chainlink(AddrChainlinkOracle.USDC);

        uint256 price = new OracleERC4626FromCurveLP(USDC_fxUSD, 1, usdc, "fxUSD").latestAnswer(false);
        assertApproxEqRel(price, new OracleCoinFromCurveLP(address(USDC_fxUSD), usdc, 0, "fxUSD").latestAnswer(false), 1e12);
        assertApproxEqRel(price, 1e18, 1e16);
    }

    /// @notice A pool without any price oracle can't be used.
    function test_ERC4626_market_rate_reverts_without_oracle() external {
        vm.expectRevert();
        new OracleERC4626FromCurveLP(ICurveStableSwapNG(address(AddrERC4626.sUSDe)), 1, _chainlink(AddrChainlinkOracle.USDC), "none");
    }

    /// @notice A premium / discount on the Curve EMA moves the PT price by the same %.
    function test_PT_sUSDe_market_rate_follows_LP_premium() external {
        IPriceOracle sUSDeMarkett = _sUSDeMarket();
        OraclePendlePTLinearDiscount ptOracle = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_26_11_26, sUSDeMarkett, BASE_DISCOUNT_PER_YEAR, "PT sUSDe");

        uint256 price = ptOracle.latestAnswer(false);
        uint256 ema = DOLA_sUSDe.price_oracle(0);

        // +3% premium
        vm.mockCall(address(DOLA_sUSDe), abi.encodeWithSignature("price_oracle(uint256)", 0), abi.encode((ema * 103) / 100));
        assertApproxEqRel(ptOracle.latestAnswer(false), (price * 103) / 100, 1e12);

        // -10% discount
        vm.mockCall(address(DOLA_sUSDe), abi.encodeWithSignature("price_oracle(uint256)", 0), abi.encode((ema * 90) / 100));
        assertApproxEqRel(ptOracle.latestAnswer(false), (price * 90) / 100, 1e12);
    }

    // Simulation state
    IPriceOracle sUSDeMarket;
    IPriceOracle sUSDeNAV;
    OraclePendlePTLinearDiscount ptMarket;
    OraclePendlePTLinearDiscount ptNAV;

    /// @notice Simulates sUSDe being dumped into DOLA/sUSDe (no arbitrage): the secondary rate drifts below NAV.
    ///         Compares the PT priced with the market rate vs the NAV, step by step.
    function test_sim_sUSDe_LP_drift_below_NAV() external {
        IPriceOracle usde = _chainlink(AddrChainlinkOracle.USDe);
        sUSDeMarket = _sUSDeMarket();
        sUSDeNAV = new OracleERC4626(AddrERC4626.sUSDe, usde, "sUSDe NAV / USD");
        ptMarket = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_26_11_26, sUSDeMarket, BASE_DISCOUNT_PER_YEAR, "PT market");
        ptNAV = new OraclePendlePTLinearDiscount(AddrMarketPendle.sUSDe_26_11_26, sUSDeNAV, BASE_DISCOUNT_PER_YEAR, "PT NAV");

        IERC20 sUSDe = IERC20(address(AddrERC4626.sUSDe));
        deal(address(sUSDe), address(this), 40_000_000e18);
        sUSDe.approve(address(DOLA_sUSDe), type(uint256).max);

        // Cumulative sUSDe sold: 0, 2M, 5M, 10M, 20M, 30M, 35M
        uint256[7] memory sells = [uint256(0), 2_000_000e18, 3_000_000e18, 5_000_000e18, 10_000_000e18, 10_000_000e18, 5_000_000e18];
        uint256 sold;

        console.log("sold(M) | pool sUSDe/DOLA (M) | spot | EMA +1 block | EMA +1h | sUSDe mkt vs NAV | PT market | PT NAV | NAV overvalues by");
        for (uint256 i; i < sells.length; i++) {
            if (sells[i] != 0) DOLA_sUSDe.exchange(1, 0, sells[i], 0);
            sold += sells[i];
            _simStep(sold);
        }
    }

    function _simStep(uint256 sold) internal {
        string memory line = string.concat(
            vm.toString(sold / 1e24),
            " | ",
            vm.toString(DOLA_sUSDe.balances(1) / 1e24),
            "/",
            vm.toString(DOLA_sUSDe.balances(0) / 1e24),
            " | ",
            _fmt(DOLA_sUSDe.get_p(0)),
            " | "
        );

        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);
        line = string.concat(line, _fmt(DOLA_sUSDe.price_oracle(0)), " | ");

        // Let the EMA (ma_exp_time = 866s) converge before reading the oracles
        vm.warp(block.timestamp + 1 hours);
        uint256 pm = ptMarket.latestAnswer(false);
        uint256 pn = ptNAV.latestAnswer(false);
        line = string.concat(line, _fmt(DOLA_sUSDe.price_oracle(0)), " | ", _bps(sUSDeMarket.latestAnswer(false), sUSDeNAV.latestAnswer(false)), " bps | ");
        console.log(string.concat(line, _fmt(pm), " | ", _fmt(pn), " | ", _bps(pn, pm), " bps"));
    }

    /// @dev 1e18 fixed point to "x.xxxx"
    function _fmt(uint256 x) internal pure returns (string memory) {
        uint256 dec = (x % 1e18) / 1e14;
        return
            string.concat(
                vm.toString(x / 1e18),
                ".",
                dec < 10
                    ? "000"
                    : dec < 100
                        ? "00"
                        : dec < 1000
                            ? "0"
                            : "",
                vm.toString(dec)
            );
    }

    /// @param syOracle    Prices the SY yield token, the PT oracle derives the accounting asset price from it
    /// @param assetOracle Prices the accounting asset, used to build the Pendle TWAP reference
    /// @param discount    Linear discount per year, must be above the market implied one
    function _diff(IPendleMarketV3 market, IPriceOracle syOracle, IPriceOracle assetOracle, uint96 discount, string memory name) internal {
        OraclePendlePTLinearDiscount ptOracle = new OraclePendlePTLinearDiscount(market, syOracle, discount, name);

        uint256 assetPrice = assetOracle.latestAnswer(false);
        uint256 ptToAsset = pendleOracle.getPtToAssetRate(address(market), TWAP_DURATION);

        uint256 oraclePrice = ptOracle.latestAnswer(false);
        uint256 apiPrice = _ffiPTPrice(address(market));
        uint256 twapPrice = (ptToAsset * assetPrice) / 1e18;

        uint256 timeLeft = market.expiry() - block.timestamp;
        console.log(name);
        console.log("  oracle price      ", oraclePrice);
        console.log("  pendle API price  ", apiPrice);
        console.log("  pendle TWAP price ", twapPrice);
        console.log("  delta vs API (bps)", _bps(oraclePrice, apiPrice));
        console.log("  delta vs TWAP(bps)", _bps(oraclePrice, twapPrice));
        // Linear discount rate the market currently implies: above it the oracle overprices the PT
        console.log("  market linear rate", ((1e18 - ptToAsset) * 365 days) / timeLeft);

        assertApproxEqRel(oraclePrice, apiPrice, 1e16, "oracle vs Pendle API > 1%");
        assertApproxEqRel(oraclePrice, twapPrice, 1e16, "oracle vs Pendle TWAP > 1%");
        // With a discount rate above the implied one, the oracle must never overprice the PT
        assertLe(oraclePrice, twapPrice, "oracle overprices PT");

        _assertMaturity(market, ptOracle, syOracle);
    }

    /// @dev At maturity, 1 PT is worth exactly the SY price converted in accounting asset
    function _assertMaturity(IPendleMarketV3 market, OraclePendlePTLinearDiscount ptOracle, IPriceOracle syOracle) internal {
        IPendleSYToken sy = _sy(market);
        vm.warp(market.expiry());
        (, , uint8 assetDecimals) = sy.assetInfo();
        assertEq(ptOracle.latestAnswer(false), (syOracle.latestAnswer(false) * 10 ** (18 + assetDecimals - sy.decimals())) / sy.exchangeRate(), "PT != asset at maturity");
    }

    /// @dev sUSDe market rate: DOLA/sUSDe EMA, DOLA from DOLA/sUSDS EMA, USDS from Chainlink
    function _sUSDeMarket() internal returns (IPriceOracle) {
        IPriceOracle dola = new OracleCoinFromCurveLP(address(AddrCurveStableLP.DOLA_sUSDS), _chainlink(AddrChainlinkOracle.USDS), 1, "DOLA / USD");
        return new OracleERC4626FromCurveLP(DOLA_sUSDe, 1, dola, "sUSDe / USD");
    }

    function _chainlink(IAggregatorV3 feed) internal returns (IPriceOracle) {
        return new OracleChainlinkWrapper(feed, 1000000000000, address(0), "Chainlink / USD");
    }

    function _sy(IPendleMarketV3 market) internal view returns (IPendleSYToken) {
        (address sy, , ) = market.readTokens();
        return IPendleSYToken(sy);
    }

    function _ffiPTPrice(address market) internal returns (uint256) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/pendle/printPTPrice.mjs";
        inputs[2] = vm.toString(block.chainid);
        inputs[3] = vm.toString(market);
        return abi.decode(vm.ffi(inputs), (uint256));
    }

    /// @dev Signed difference of `a` against `b` in bps, as a string for logging.
    function _bps(uint256 a, uint256 b) internal pure returns (string memory) {
        return a >= b ? vm.toString(((a - b) * 1e4) / b) : string.concat("-", vm.toString(((b - a) * 1e4) / b));
    }
}

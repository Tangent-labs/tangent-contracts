// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePT
/// @author Tangent Finance
/// @notice This contract prices a PT of Pendle in $, using the PT/SY rate of its Pendle market paired
///         with a $ oracle of the SY.
/// @dev    Price = PT/SY rate (Pendle) * $ price of one SY.
///
///         `underlyingOracle` MUST price **one SY unit**, not the market's accounting asset.
///         A SY is minted 1:1 against its yield-bearing token, so in practice the oracle to plug is the
///         one of that token (e.g. `OracleERC4626(sUSDe)` for the SY of a PT-sUSDe market, and the plain
///         USDe oracle for the SY of a PT-USDe market since that SY is 1:1 with USDe).
///         Feeding the asset oracle instead (e.g. WBTC for a SY wrapping a BTC vault) silently drops the
///         SY exchange rate, and the error grows as the SY accrues yield.
///
///         `denominatorScale` = 36 - decimals of `SY.exchangeRate()`.
///         Pendle computes `getPtToSyRate = getPtToAssetRate * 1e18 / SY.exchangeRate()`, and while
///         `getPtToAssetRate` is always 1e18 based, `SY.exchangeRate()` follows the decimals of the
///         accounting asset. So the rate is 1e18 based for an 18 decimals asset (=> 18), but 1e28 based
///         for an 8 decimals one such as BTC (=> 28).
///
///         Both `underlyingOracle` and this oracle return 18 decimals prices per whole token.
contract OraclePendlePT is OracleBase {
    error InvalidUnderlyingOracleDecimals();
    error InvalidDenominatorScale();

    /// @dev Pendle `PendlePYLpOracle`, deployed at the same address on every chain supported by Pendle.
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    /// @dev `denominatorScale` + decimals of the market accounting asset. See the contract level doc.
    uint256 internal constant SCALE_SUM = 36;

    OraclePendlePTStruct public params;
    struct OraclePendlePTStruct {
        IPendleMarketV3 pendleMarket;
        IPriceOracle underlyingOracle;
        // TWAP window of the Pendle oracle, in seconds. Downcast to uint32 when queried.
        uint88 duration;
        // See the contract level doc: 36 - decimals of `SY.exchangeRate()`.
        uint8 denominatorScale;
    }

    /// @dev Before deploying, `oracle.getOracleState(_pendleMarket, _duration)` must report
    ///      `oldestObservationSatisfied == true` and `increaseCardinalityRequired == false`, otherwise the
    ///      market observation buffer cannot serve `_duration` and pricing reverts (see `_computePrice`).
    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint88 _duration, uint8 _denominatorScale, string memory _oracleName) OracleBase(_oracleName) {
        // The whole contract assumes prices are 18 decimals based, as advertised by `decimals()`.
        require(_underlyingOracle.decimals() == 18, InvalidUnderlyingOracleDecimals());

        // The scale of the PT/SY rate is dictated by the decimals of the market accounting asset, so
        // `_denominatorScale` is checked against the market instead of being trusted from the deployer.
        // The addition can not overflow, both operands are bounded by `type(uint8).max`.
        (address sy, , ) = _pendleMarket.readTokens();
        (, , uint8 assetDecimals) = IPendleSYToken(sy).assetInfo();
        require(uint256(_denominatorScale) + uint256(assetDecimals) == SCALE_SUM, InvalidDenominatorScale());

        params = OraclePendlePTStruct({pendleMarket: _pendleMarket, underlyingOracle: _underlyingOracle, duration: _duration, denominatorScale: _denominatorScale});
    }

    /**
     * @notice Returns the latest price of a PT in $.
     * @return The price of the PT.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params);
    }

    /**
     * @notice Returns the latest price of a PT in $ and stores the last good value of the underlying oracle if needed.
     * @return The price of the PT.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params);
    }

    /**
     * @dev Maturity is handled by Pendle itself, no branching is needed here:
     *      - Before maturity, the PT/SY rate is derived from the TWAP of the market implied rate over
     *        `duration`, so it discounts the PT and converges to par as maturity approaches. This branch
     *        reverts when the market observation buffer does not cover `duration`, including when
     *        `isNoFailMode` is true.
     *      - After maturity, the PT is redeemable 1:1 against the accounting asset: Pendle returns
     *        `1e18 * 1e18 / SY.exchangeRate()`, `duration` is ignored and no TWAP is read, so this branch
     *        cannot revert. The price stays constant in asset terms and decreases in SY terms as the SY
     *        keeps accruing, which is the expected behaviour: a matured PT stops earning yield.
     *      Rounding is a truncation, so the price is rounded down, which is the conservative side for a collateral.
     *
     *      The price is capped by the price of the SY: 1 PT is redeemable against 1 accounting asset at
     *      maturity and 1 SY is worth at least 1 accounting asset, so a PT can never be worth more than the
     *      SY it is priced against. Without that cap, a market whose TWAPed implied rate turns negative
     *      (thin liquidity, manipulation) would over value the collateral.
     */
    function _computePrice(uint256 underlyingPrice, OraclePendlePTStruct memory _params) internal view returns (uint256) {
        uint256 price = (oracle.getPtToSyRate(address(_params.pendleMarket), uint32(_params.duration)) * underlyingPrice) / (10 ** _params.denominatorScale);
        return price > underlyingPrice ? underlyingPrice : price;
    }
}

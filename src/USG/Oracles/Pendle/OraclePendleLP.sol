// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendleLP
/// @author Tangent Finance
/// @notice This contract prices a LP of Pendle in $, using the LP/SY rate of its Pendle market paired
///         with a $ oracle of the SY.
/// @dev    Price = LP/SY rate (Pendle) * $ price of one SY.
///
///         `underlyingOracle` MUST price **one SY unit**, not the market's accounting asset.
///         A SY is minted 1:1 against its yield-bearing token, so in practice the oracle to plug is the
///         one of that token (e.g. `OracleERC4626(sUSDS)` for the SY of a sUSDS market, and the plain
///         USDe oracle for the SY of a USDe market since that SY is 1:1 with USDe).
///         Feeding the asset oracle instead (e.g. WBTC for a SY wrapping a BTC vault) silently drops the
///         SY exchange rate, and the error grows as the SY accrues yield.
///
///         `denominatorScale` = 36 - decimals of `SY.exchangeRate()`.
///         Pendle computes `getLpToSyRate = getLpToAssetRate * 1e18 / SY.exchangeRate()`, and while
///         `getLpToAssetRate` is always 1e18 based, `SY.exchangeRate()` follows the decimals of the
///         accounting asset. So the rate is 1e18 based for an 18 decimals asset (=> 18), 1e30 based for a
///         6 decimals one (=> 30) and 1e28 based for an 8 decimals one such as BTC (=> 28).
///
///         Unlike a PT, a LP is not capped by the SY: it represents a share of the SY + PT reserves of the
///         market plus the swap fees accrued since inception, so one LP is usually worth several SY.
///
///         A Pendle LP has 18 decimals and both `underlyingOracle` and this oracle return 18 decimals
///         prices per whole token.
contract OraclePendleLP is OracleBase {
    error InvalidUnderlyingOracleDecimals();
    error InvalidDenominatorScale();

    /// @dev Pendle `PendlePYLpOracle`, deployed at the same address on every chain supported by Pendle.
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    /// @dev `denominatorScale` + decimals of the market accounting asset. See the contract level doc.
    uint256 internal constant SCALE_SUM = 36;

    OraclePendleLPStruct public params;
    struct OraclePendleLPStruct {
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

        // The scale of the LP/SY rate is dictated by the decimals of the market accounting asset, so
        // `_denominatorScale` is checked against the market instead of being trusted from the deployer.
        // The addition can not overflow, both operands are bounded by `type(uint8).max`.
        (address sy, , ) = _pendleMarket.readTokens();
        (, , uint8 assetDecimals) = IPendleSYToken(sy).assetInfo();
        require(uint256(_denominatorScale) + uint256(assetDecimals) == SCALE_SUM, InvalidDenominatorScale());

        params = OraclePendleLPStruct({pendleMarket: _pendleMarket, underlyingOracle: _underlyingOracle, duration: _duration, denominatorScale: _denominatorScale});
    }

    /**
     * @notice Returns the latest price of a LP in $.
     * @return The price of the LP.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendleLPStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params);
    }

    /**
     * @notice Returns the latest price of a LP in $ and stores the last good value of the underlying oracle if needed.
     * @return The price of the LP.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OraclePendleLPStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params);
    }

    /**
     * @dev Maturity is handled by Pendle itself, no branching is needed here:
     *      - Before maturity, the PT leg of the reserves is valued with the TWAP of the market implied
     *        rate over `duration`, which is what makes the rate manipulation resistant. This branch
     *        reverts when the market observation buffer does not cover `duration`, including when
     *        `isNoFailMode` is true.
     *      - After maturity, the PT leg is redeemable 1:1 against the accounting asset, so `duration` is
     *        ignored, no TWAP is read and this branch cannot revert. The LP keeps a meaningful value,
     *        it stays redeemable against its SY + PT reserves.
     *      Rounding is a truncation, so the price is rounded down, which is the conservative side for a collateral.
     *
     *      No cap is applied here, contrary to `OraclePendlePT`: the LP/SY rate is not bounded by 1, one LP
     *      is a share of the whole reserves of the market and is normally worth several SY.
     */
    function _computePrice(uint256 underlyingPrice, OraclePendleLPStruct memory _params) internal view returns (uint256) {
        return (oracle.getLpToSyRate(address(_params.pendleMarket), uint32(_params.duration)) * underlyingPrice) / (10 ** _params.denominatorScale);
    }
}

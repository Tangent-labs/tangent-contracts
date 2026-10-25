// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";
import {IPendleYTToken} from "../../../interfaces/externals/Pendle/IPendleYTToken.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePTLinearDiscount
/// @author Tangent Finance
/// @notice This contract prices a PT of Pendle in $. A linear discount of its price compared to the SY accounting asset is used, going to 1 at maturity.
/// @dev    `underlyingOracle` must price the SY yield token (ex sUSDe), the accounting asset price (ex USDe) is derived with the Pendle PY index.
contract OraclePendlePTLinearDiscount is OracleBase {
    IPriceOracle public immutable underlyingOracle;
    uint256 public immutable baseDiscountPerYear;
    IPendleSYToken public immutable sy;
    IPendleYTToken public immutable yt;
    uint256 public immutable maturity;
    // `exchangeRate` is raw asset per raw SY: 18 + asset decimals - SY decimals gives the price of 1 whole asset
    uint256 public immutable exchangeRateScaleExp;

    error DiscountMoreThan100Percent();
    error InvalidOracleDecimals();

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint256 _baseDiscountPerYear, string memory _oracleName) OracleBase(_oracleName) {
        require(_baseDiscountPerYear <= 1 ether, DiscountMoreThan100Percent());
        require(_underlyingOracle.decimals() == 18, InvalidOracleDecimals());
        uint256 _maturity = _pendleMarket.expiry();
        (address _sy, , address _yt) = _pendleMarket.readTokens();
        (, , uint8 assetDecimals) = IPendleSYToken(_sy).assetInfo();

        underlyingOracle = _underlyingOracle;
        baseDiscountPerYear = _baseDiscountPerYear;
        sy = IPendleSYToken(_sy);
        yt = IPendleYTToken(_yt);
        maturity = _maturity;
        exchangeRateScaleExp = 18 + assetDecimals - IPendleSYToken(_sy).decimals();
        // The time left only decreases, so checking the discount at deployment is enough to never underflow.
        require(_getCurrentDiscount(_maturity, _baseDiscountPerYear) < 1 ether, DiscountMoreThan100Percent());
    }

    function getCurrentDiscount() external view returns (uint256) {
        return _getCurrentDiscount(maturity, baseDiscountPerYear);
    }

    function _getCurrentDiscount(uint256 _maturity, uint256 _baseDiscountPerYear) internal view returns (uint256) {
        // Computes the time that left before the PT maturity
        uint256 timeLeft = _maturity > block.timestamp ? _maturity - block.timestamp : 0;

        // Computes the % discount estimation of the PT compared to its accounting asset.
        return (timeLeft * _baseDiscountPerYear) / 365 days;
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Asset price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the SY accounting asset.
     * @return The price of the PT in $.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        return _computePrice(underlyingOracle.latestAnswer(isNoFailMode));
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Asset price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the SY accounting asset.
     * @return The price of the PT in $.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        return _computePrice(underlyingOracle.latestAnswerUpdate(isNoFailMode));
    }

    function _computePrice(uint256 syPrice) internal view returns (uint256) {
        // 1 PT redeems 1 / pyIndex SY at maturity. Pendle's pyIndex never decreases, so if the SY rate drops the PT takes the loss.
        uint256 exchangeRate = sy.exchangeRate();
        uint256 pyIndexStored = yt.pyIndexStored();
        // Takes the max(exchangeRate, pyIndexStored)
        uint256 pyIndex = exchangeRate > pyIndexStored ? exchangeRate : pyIndexStored;
        uint256 assetPrice = (syPrice * 10 ** exchangeRateScaleExp) / pyIndex;
        return (assetPrice * (1 ether - _getCurrentDiscount(maturity, baseDiscountPerYear))) / 1 ether;
    }
}

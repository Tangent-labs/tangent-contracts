// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePTLinearDiscount
/// @author Tangent Finance
/// @notice This contract prices a PT of Pendle in $. A linear discount of its price compared to the SY accounting asset is used, going to 1 at maturity.
/// @dev    `underlyingOracle` must price the SY yield token (ex sUSDe), the accounting asset price (ex USDe) is derived with `SY.exchangeRate()`.
contract OraclePendlePTLinearDiscount is OracleBase {
    OraclePendlePTLinearDiscountStruct public params;

    error DiscountMoreThan100Percent();
    error InvalidOracleDecimals();
    // 2 slots: [underlyingOracle | baseDiscountPerYear] [sy | maturity | exchangeRateScaleExp]
    struct OraclePendlePTLinearDiscountStruct {
        IPriceOracle underlyingOracle;
        uint96 baseDiscountPerYear;
        IPendleSYToken sy;
        uint88 maturity;
        // `exchangeRate` is raw asset per raw SY: 18 + asset decimals - SY decimals gives the price of 1 whole asset
        uint8 exchangeRateScaleExp;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint96 _baseDiscountPerYear, string memory _oracleName) OracleBase(_oracleName) {
        require(_baseDiscountPerYear <= 1 ether, DiscountMoreThan100Percent());
        require(_underlyingOracle.decimals() == 18, InvalidOracleDecimals());
        uint256 maturity = _pendleMarket.expiry();
        (address _sy, , ) = _pendleMarket.readTokens();
        (, , uint8 assetDecimals) = IPendleSYToken(_sy).assetInfo();

        params = OraclePendlePTLinearDiscountStruct({
            underlyingOracle: _underlyingOracle,
            baseDiscountPerYear: _baseDiscountPerYear,
            sy: IPendleSYToken(_sy),
            maturity: uint88(maturity),
            exchangeRateScaleExp: uint8(18 + assetDecimals - IPendleSYToken(_sy).decimals())
        });
        // The time left only decreases, so checking the discount at deployment is enough to never underflow.
        require(_getCurrentDiscount(maturity, _baseDiscountPerYear) < 1 ether, DiscountMoreThan100Percent());
    }

    function getCurrentDiscount() external view returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        return _getCurrentDiscount(_params.maturity, _params.baseDiscountPerYear);
    }

    function _getCurrentDiscount(uint256 maturity, uint256 baseDiscountPerYear) internal view returns (uint256) {
        // Computes the time that left before the PT maturity
        uint256 timeLeft = maturity > block.timestamp ? maturity - block.timestamp : 0;

        // Computes the % discount estimation of the PT compared to its accounting asset.
        return (timeLeft * baseDiscountPerYear) / 365 days;
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Asset price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the SY accounting asset.
     * @return The price of the PT in $.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params);
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Asset price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the SY accounting asset.
     * @return The price of the PT in $.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params);
    }

    function _computePrice(uint256 syPrice, OraclePendlePTLinearDiscountStruct memory _params) internal view returns (uint256) {
        // Price of 1 accounting asset, which is what 1 PT redeems for at maturity
        uint256 assetPrice = (syPrice * 10 ** _params.exchangeRateScaleExp) / _params.sy.exchangeRate();
        return (assetPrice * (1 ether - _getCurrentDiscount(_params.maturity, _params.baseDiscountPerYear))) / 1 ether;
    }
}

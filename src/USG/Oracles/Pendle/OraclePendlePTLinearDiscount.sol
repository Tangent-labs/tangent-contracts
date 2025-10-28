// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePTLinearDiscount
/// @notice This contract prices a PT of Pendle in $. An exponation of its price compared to the underlying is used, going to 1 at maturity.
contract OraclePendlePTLinearDiscount is OracleBase {
    OraclePendlePTLinearDiscountStruct public params;
    struct OraclePendlePTLinearDiscountStruct {
        uint96 underlyingOracleDecimals;
        IPriceOracle underlyingOracle;
        uint88 maturity;
        uint256 baseDiscountPerYear;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint256 _baseDiscountPerYear) {
        require(_baseDiscountPerYear <= 1 ether);
        params = OraclePendlePTLinearDiscountStruct({
            underlyingOracle: _underlyingOracle,
            underlyingOracleDecimals: _underlyingOracle.decimals(),
            maturity: uint88(_pendleMarket.expiry()),
            baseDiscountPerYear: _baseDiscountPerYear
        });
    }

    function getCurrentDiscount() external view returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        return _getCurrentDiscount(_params.maturity, _params.baseDiscountPerYear);
    }

    function _getCurrentDiscount(uint256 maturity, uint256 baseDiscountPerYear) internal view returns (uint256) {
        // Computes the time that left before the PT maturity
        uint256 timeLeft = maturity > block.timestamp ? maturity - block.timestamp : 0;

        // Computes the % discount estimation of the PT compared to its underlying.
        return (timeLeft * baseDiscountPerYear) / 365 days;
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Underlying price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the underlying.
     * @return The price of the PT in $.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        uint256 underlyingPrice = _params.underlyingOracle.latestAnswer(isNoFailMode);

        return (underlyingPrice * (1e18 - _getCurrentDiscount(_params.maturity, _params.baseDiscountPerYear))) / 1e18;
    }
}

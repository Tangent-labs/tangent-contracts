// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePTLinearDiscount
/// @author Tangent Finance
/// @notice This contract prices a PT of Pendle in $. An exponation of its price compared to the underlying is used, going to 1 at maturity.
contract OraclePendlePTLinearDiscount is OracleBase {
    OraclePendlePTLinearDiscountStruct public params;

    error DiscountMoreThan100Percent();
    struct OraclePendlePTLinearDiscountStruct {
        uint96 underlyingOracleDecimals;
        IPriceOracle underlyingOracle;
        uint40 maturity;
        uint216 baseDiscountPerYear;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint216 _baseDiscountPerYear, string memory _oracleName) OracleBase(_oracleName) {
        require(_baseDiscountPerYear <= 1 ether, DiscountMoreThan100Percent());
        params = OraclePendlePTLinearDiscountStruct({
            underlyingOracle: _underlyingOracle,
            underlyingOracleDecimals: _underlyingOracle.decimals(),
            maturity: uint40(_pendleMarket.expiry()),
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
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params.maturity, _params.baseDiscountPerYear);
    }

    /**
     * @notice Returns an esimation of a PT price from Pendle by representing the PT=>Underlying price with a
     *         linear function reaching 1 at maturity.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the underlying.
     * @return The price of the PT in $.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OraclePendlePTLinearDiscountStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params.maturity, _params.baseDiscountPerYear);
    }

    function _computePrice(uint256 underlyingPrice, uint40 maturity, uint216 baseDiscountPerYear) internal view returns (uint256) {
        return (underlyingPrice * (1 ether - _getCurrentDiscount(maturity, baseDiscountPerYear))) / 1 ether;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OraclePendlePT
/// @author Tangent Finance
/// @notice This contract prices a PT of Pendle through it's LP paired with it's SY.
contract OraclePendlePT is OracleBase {
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    OraclePendlePTStruct public params;
    struct OraclePendlePTStruct {
        IPendleMarketV3 pendleMarket;
        IPriceOracle underlyingOracle;
        uint88 duration;
        uint8 denominatorScale;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint88 _duration, uint8 _denominatorScale, string memory _oracleName) OracleBase(_oracleName) {
        params = OraclePendlePTStruct({pendleMarket: _pendleMarket, underlyingOracle: _underlyingOracle, duration: _duration, denominatorScale: _denominatorScale});
    }

    /**
     * @notice Returns the latest price of a PT.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the underlying.
     * @return The price of the PT.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params);
    }

    /**
     * @notice Returns the latest price of a PT.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the underlying.
     * @return The price of the PT.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params);
    }

    function _computePrice(uint256 underlyingPrice, OraclePendlePTStruct memory _params) internal view returns (uint256) {
        return (oracle.getPtToSyRate(address(_params.pendleMarket), uint32(_params.duration)) * underlyingPrice) / (10 ** _params.denominatorScale);
    }
}

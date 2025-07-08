// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OracleDuoPoolStable
/// @notice This contract provides price oracle functionality a PT from PENDLE.
contract OraclePendlePT is OracleBase {
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    OraclePendlePTStruct public params;
    struct OraclePendlePTStruct {
        IPendleMarketV3 pendleMarket;
        uint96 underlyingOracleDecimals;
        IPriceOracle underlyingOracle;
        uint96 duration;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle, uint96 _duration) {
        params = OraclePendlePTStruct({
            pendleMarket: _pendleMarket,
            underlyingOracle: _underlyingOracle,
            underlyingOracleDecimals: _underlyingOracle.decimals(),
            duration: _duration
        });
    }

    /**
     * @notice Returns the latest price of a PT.
     * @dev    When the PT is expired, 1PT is redeemable 1:1 against the underlying.
     * @return The price of the PT.
     */
    function latestAnswer() external view override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        uint256 underlyingPrice = _coinPrice(_params.underlyingOracle, _params.underlyingOracleDecimals);

        if (_params.pendleMarket.isExpired()) {
            return underlyingPrice;
        }

        return (oracle.getPtToSyRate(address(_params.pendleMarket), uint32(_params.duration)) * underlyingPrice) / 1e18;
    }
}

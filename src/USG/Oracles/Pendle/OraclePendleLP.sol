// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OracleDuoPoolStable
/// @notice This contract provides price oracle functionality for a dual pool stablecoin setup.
contract OraclePendleLP is OracleBase {
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    OraclePendlePTStruct public params;
    struct OraclePendlePTStruct {
        IPendleMarketV3 pendleMarket;
        IPriceOracle underlyingOracle;
        uint96 underlyingOracleDecimals;
    }

    constructor(IPendleMarketV3 _pendleMarket, IPriceOracle _underlyingOracle) {
        params = OraclePendlePTStruct({pendleMarket: _pendleMarket, underlyingOracle: _underlyingOracle, underlyingOracleDecimals: _underlyingOracle.decimals()});
    }

    /**
     * @notice Returns the latest price from the oracle
     * @return The price of the stable pool, adjusted to 18 decimals
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OraclePendlePTStruct memory _params = params;
        uint256 underlyingPrice = _params.underlyingOracle.latestAnswer(isNoFailMode);

        //TODO We need to find what to do after expiration
        // if (_params.pendleMarket.isExpired()) {
        //     return underlyingPrice;
        // }

        return (oracle.getLpToSyRate(address(_params.pendleMarket), 30) * underlyingPrice) / 1e18;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import {OracleBase} from "../OracleBase.sol";

struct ChainlinkAggregatorWrapperStruct {
    IAggregatorV3 chainlinkOracle;
    uint oracleDecimals;
    uint heartbeat;
}
/// @title OracleCoinFromCurveLP
/// @notice This contract provides price oracle functionality for an ERC20, from a pool of Curve
contract ChainlinkAggregatorWrapper is OracleBase {
    error NegativePrice();
    error StalePrice();
    ChainlinkAggregatorWrapperStruct public oracleParams;
    constructor(IAggregatorV3 _chainlinkOracle) {
        oracleParams = ChainlinkAggregatorWrapperStruct({chainlinkOracle: _chainlinkOracle, oracleDecimals: _chainlinkOracle.decimals(), heartbeat: 100});
    }

    /**
     * @notice Returns a time weighted price of a token present in a Curve pool
     * @dev    Using the price_oracle, we can are protected from flash attacks.
     * @return The price of the token from the pool.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        ChainlinkAggregatorWrapperStruct memory _params = oracleParams;

        (uint80 roundId, int256 rawPrice, , uint256 updateTime, uint80 answeredInRound) = _params.chainlinkOracle.latestRoundData();

        uint256 price;
        if (isNoFailMode) {
            price = uint256(rawPrice);
        } else {
            require(rawPrice > 0, NegativePrice());
            require(updateTime != 0, "Incomplete round");
            require(answeredInRound >= roundId, "Stale price");
            require(updateTime <= block.timestamp, StalePrice());
            price = uint256(rawPrice);
        }

        return uint256(rawPrice);
    }
}

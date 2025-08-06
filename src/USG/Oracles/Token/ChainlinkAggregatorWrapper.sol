// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import {OracleBase} from "../OracleBase.sol";

struct ChainlinkAggregatorWrapperStruct {
    IAggregatorV3 chainlinkOracle;
    uint48 oracleDecimals;
    uint48 heartbeat;
}
/// @title ChainlinkAggregatorWrapper
/// @notice This contract is a wrapper of a Chainlink aggregator checking if the last price is stale or invalid.
contract ChainlinkAggregatorWrapper is OracleBase {
    error NegativePrice();
    error StalePrice();
    error IncompleteRound();
    error InvalidRound();

    ChainlinkAggregatorWrapperStruct public oracleParams;
    constructor(IAggregatorV3 _chainlinkOracle, uint48 heartbeat) {
        oracleParams = ChainlinkAggregatorWrapperStruct({chainlinkOracle: _chainlinkOracle, oracleDecimals: _chainlinkOracle.decimals(), heartbeat: heartbeat});
    }

    /**
     * @notice Fetch and verify the price provided by a Chainlink Aggregator.
     *         Fails when roundId is incorrect or when the updateTime is stale.
     * @dev    Adjust the decimals to 18 if needed.
     * @return The price of the token from chainlink
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        ChainlinkAggregatorWrapperStruct memory _params = oracleParams;

        (uint80 roundId, int256 rawPrice, , uint256 updateTime, uint80 answeredInRound) = _params.chainlinkOracle.latestRoundData();

        uint256 price;
        if (isNoFailMode) {
            price = uint256(rawPrice);
        } else {
            require(rawPrice > 0, NegativePrice());
            require(updateTime != 0, IncompleteRound());
            require(answeredInRound >= roundId, InvalidRound());
            require(updateTime + _params.heartbeat >= block.timestamp, StalePrice());
            price = uint256(rawPrice);
        }

        return uint256(rawPrice) * 10 ** (18 - _params.oracleDecimals);
    }
}

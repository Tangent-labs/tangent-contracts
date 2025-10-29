// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import {OracleBase, IPriceOracle} from "../OracleBase.sol";

struct OracleChainlinkWrapperStruct {
    IAggregatorV3 chainlinkOracle;
    uint96 oracleDecimals;
    uint96 heartbeat;
    IPriceOracle oracleFallback;
}

/// @title OracleChainlinkWrapper
/// @notice This contract is a wrapper of a Chainlink aggregator checking if the last price is stale or invalid.
contract OracleChainlinkWrapper is OracleBase {
    error InvalidAggregatorValue();

    OracleChainlinkWrapperStruct public oracleParams;
    constructor(IAggregatorV3 _chainlinkOracle, uint96 heartbeat, IPriceOracle oracleFallback) {
        oracleParams = OracleChainlinkWrapperStruct({
            chainlinkOracle: _chainlinkOracle,
            oracleDecimals: _chainlinkOracle.decimals(),
            heartbeat: heartbeat,
            oracleFallback: oracleFallback
        });
    }

    /**
     * @notice Fetch and verify the price provided by a Chainlink Aggregator.
     *         Fails when roundId is incorrect or when the updateTime is stale.
     * @param  isNoFailMode When true, the transaction cannot fail. When false, tx will revert in case of stale price.
     * @return price of the token from chainlink
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleChainlinkWrapperStruct memory _params = oracleParams;

        // Retrieve price and round infos of the Chainlink aggregator
        (uint80 roundId, int256 rawPrice, , uint256 updateTime, uint80 answeredInRound) = _params.chainlinkOracle.latestRoundData();

        uint256 price;

        // Price valid
        if (_isPriceValid(rawPrice, updateTime, answeredInRound, roundId, _params.heartbeat)) {
            price = uint256(rawPrice);
        }
        // Price invalid
        else {
            // If a fallback is setup, we fetch its price
            if (address(0) != address(_params.oracleFallback)) {
                return _params.oracleFallback.latestAnswer(isNoFailMode);
            }
            // When no fallback
            else {
                if (isNoFailMode) {
                    price = uint256(rawPrice);
                } else {
                    revert InvalidAggregatorValue();
                }
            }
        }

        return price * 10 ** (18 - _params.oracleDecimals);
    }

    function _isPriceValid(int256 rawPrice, uint256 updateTime, uint80 answeredInRound, uint80 roundId, uint96 hb) internal view returns (bool) {
        return (rawPrice > 0 && // Price over 0
            updateTime != 0 && // Update time different from 0
            answeredInRound >= roundId && // Correct round ID
            updateTime + hb >= block.timestamp); // Price not stale
    }
}

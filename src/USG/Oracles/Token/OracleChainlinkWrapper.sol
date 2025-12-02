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
/// @author Tangent Finance
/// @notice This contract is a wrapper of a Chainlink aggregator checking if the last price is stale or invalid.
contract OracleChainlinkWrapper is OracleBase {
    error InvalidAggregatorValue();

    OracleChainlinkWrapperStruct public oracleParams;
    uint256 public lastGoodValue;

    constructor(IAggregatorV3 _chainlinkOracle, uint96 heartbeat, address oracleFallback, string memory _oracleName) OracleBase(_oracleName) {
        uint96 oracleDecimals = _chainlinkOracle.decimals();
        oracleParams = OracleChainlinkWrapperStruct({
            chainlinkOracle: _chainlinkOracle,
            oracleDecimals: oracleDecimals,
            heartbeat: heartbeat,
            oracleFallback: IPriceOracle(oracleFallback)
        });

        // Retrieve price and round infos of the Chainlink aggregator
        uint256 price = _getChainlinkPriceNormalized(_chainlinkOracle, heartbeat, oracleDecimals);
        require(price != 0, InvalidAggregatorValue());
        // Initialize the lastGoodValue
        lastGoodValue = price;
    }

    /**
     * @notice Fetch and verify the price provided by a Chainlink Aggregator.
     *         Fails when roundId is incorrect or when the updateTime is stale.
     *.        If it fails, the fallback will be called.
     * @param  isNoFailMode When true, the transaction cannot fail. When false, tx will revert in case of stale price.
     * @return price of the token from chainlink
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleChainlinkWrapperStruct memory _params = oracleParams;
        uint256 price = _getChainlinkPriceNormalized(_params.chainlinkOracle, _params.heartbeat, _params.oracleDecimals);

        // If price is 0, it's invalid
        if (price == 0) {
            // If a fallback is setup, we fetch its price
            if (address(0) != address(_params.oracleFallback)) {
                try _params.oracleFallback.latestAnswer(isNoFailMode) returns (uint256 fallbackPrice) {
                    // Price returned by the fallback is 18 decimals
                    price = fallbackPrice;
                } catch {
                    // Even the fallback failed to return a correct value
                    price = _criticalPath(isNoFailMode);
                }
            }
            // When no fallback
            else {
                price = _criticalPath(isNoFailMode);
            }
        }

        return price;
    }

    /**
     * @notice Fetch and verify the price provided by a Chainlink Aggregator.
     *         Fails when roundId is incorrect or when the updateTime is stale.
     *         If it fails, the fallback will be called.
     *         Updates the `lastGoodValue` if possible.
     * @param  isNoFailMode When true, the transaction cannot fail. When false, tx will revert in case of stale price.
     * @return price of the token from chainlink
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleChainlinkWrapperStruct memory _params = oracleParams;

        // Retrieve price and round infos of the Chainlink aggregator
        uint256 price = _getChainlinkPriceNormalized(_params.chainlinkOracle, _params.heartbeat, _params.oracleDecimals);

        // Price valid
        if (price != 0) {
            // We update the last good value with the Chainlink Oracle price normalized
            lastGoodValue = price;
        }
        // Price invalid
        else {
            // If a fallback is setup, we fetch its price
            if (address(0) != address(_params.oracleFallback)) {
                try _params.oracleFallback.latestAnswer(isNoFailMode) returns (uint256 fallbackPrice) {
                    // Price returned by the fallback is 18 decimals
                    price = fallbackPrice;
                    // We update the last good value
                    lastGoodValue = price;
                } catch {
                    price = _criticalPath(isNoFailMode);
                }
            }
            // When no fallback
            else {
                price = _criticalPath(isNoFailMode);
            }
        }

        return price;
    }

    /**
     * @dev    Retrieve the last round data from Chainlink.
     *         Verify the validity of the price
     *         If the price is valid, normalized it to 18 decimals
     *         If it's invalid, return 0
     * @param  chainlinkOracle   Chainlink Aggregator
     * @param  heartbeat         Maximum time from last round to be considered valid
     * @param  chainlinkDecimals Decimals of the chainlink oracle
     * @return price of the Chainlink Oracle normalized
     */
    function _getChainlinkPriceNormalized(IAggregatorV3 chainlinkOracle, uint96 heartbeat, uint256 chainlinkDecimals) internal view returns (uint256) {
        // Retrieve price and round infos of the Chainlink aggregator
        (, int256 rawPrice, , uint256 updateTime, ) = chainlinkOracle.latestRoundData();
        // Verify the validity of the price
        bool isValid = _isPriceValid(rawPrice, updateTime, heartbeat);

        // Price valid, we so adjust it to be under 18 decimals
        if (isValid) {
            return uint256(rawPrice) * 10 ** (18 - chainlinkDecimals);
        }
        // Price is invalid, we return 0
        else {
            return 0;
        }
    }

    /**
     * @dev    Returns the lastGoodValue if `isNoFailMode` mode to `false` and revert if `isNoFailMode` to `true`.
     * @param  isNoFailMode When true, the transaction cannot fail. When false, tx will revert in case of stale price on oracles.
     * @return price of the token
     */
    function _criticalPath(bool isNoFailMode) internal view returns (uint256) {
        if (isNoFailMode) {
            return lastGoodValue;
        } else {
            revert InvalidAggregatorValue();
        }
    }

    function _isPriceValid(int256 rawPrice, uint256 updateTime, uint96 hb) internal view returns (bool) {
        return (rawPrice > 0 && // Price over 0
            updateTime != 0 && // Update time different from 0
            updateTime + hb >= block.timestamp); // Price not stale
    }
}

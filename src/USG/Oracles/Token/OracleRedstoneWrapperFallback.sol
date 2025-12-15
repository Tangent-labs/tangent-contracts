// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IRedstonePriceFeedAdapter} from "../../../interfaces/externals/Redstone/IRedstonePriceFeedAdapter.sol";

/// @title  OracleRedstoneWrapperFallback
/// @author Tangent Finance
/// @notice This contract is a fallback of a Chainlink price feed using Redstone.
/// @dev    It'll not be plugged directly as an oracle to a market collateral
contract OracleRedstoneWrapperFallback {
    IRedstonePriceFeedAdapter constant redstoneAdapter = IRedstonePriceFeedAdapter(0xd72a6BA4a87DDB33e801b3f1c7750b2d0911fC6C);
    bytes32 immutable priceFeedKey;
    string public oracleName;
    error InvalidAggregatorValue();

    constructor(bytes32 _priceFeedKey, string memory _oracleName) {
        priceFeedKey = _priceFeedKey;
        oracleName = _oracleName;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Fetch and verify the price provided the Redstone PriceFeed.
     *         Revert if the Oracle call fails.
     * @return price of the token from redstone under 18 decimals precision
     */
    function latestAnswer(bool isFailMode) public view returns (uint256) {
        // Try to get last round data that will fail if the data is stale
        try redstoneAdapter.getLastUpdateDetails(priceFeedKey) returns (uint256, uint256, uint256 lastValue) {
            // Price valid
            // Decimals adjustment is always 10 on Redstone
            return lastValue * 10 ** 10;
        } catch {
            revert InvalidAggregatorValue();
        }
    }
}

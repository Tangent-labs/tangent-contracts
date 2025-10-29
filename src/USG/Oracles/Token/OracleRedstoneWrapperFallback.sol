// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IRedstonePriceFeedAdapter} from "../../../interfaces/externals/Redstone/IRedstonePriceFeedAdapter.sol";

import {OracleBase, IPriceOracle} from "../OracleBase.sol";

/// @title  OracleRedstoneWrapperFallback
/// @notice This contract is a fallback of a Chainlink price feed using Redstone.
/// @dev    It'll not be plugged directly as an oracle to a market collateral
contract OracleRedstoneWrapperFallback is OracleBase {
    IRedstonePriceFeedAdapter constant redstoneAdapter = IRedstonePriceFeedAdapter(0xd72a6BA4a87DDB33e801b3f1c7750b2d0911fC6C);
    bytes32 immutable priceFeedKey;

    error InvalidAggregatorValue();

    constructor(bytes32 _priceFeedKey) {
        priceFeedKey = _priceFeedKey;
    }

    /**
     * @notice Fetch and verify the price provided the Redstone PriceFeed.
     * @param  isNoFailMode When true, the transaction cannot fail. When false, tx will revert in case of stale price.
     * @return price of the token from redstone under 18 decimals precision
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        bytes32 _priceFeedKey = priceFeedKey;
        uint256 price;
        // Try to get last round data that will fail if the data is stale
        try redstoneAdapter.getLastUpdateDetails(priceFeedKey) returns (uint256, uint256, uint256 lastValue) {
            // Price valid
            price = lastValue;
        } catch {
            // Invalid Price
            // In liquidation, we want the tx to pass anyway. So it'll sucess and return a stale price.
            // This case will happen if Chainlink AND Redstone returns stale price.
            if (isNoFailMode) {
                (, , price) = redstoneAdapter.getLastUpdateDetailsUnsafe(_priceFeedKey);
            }
            // In Borrow, leverage etc, we will prefer that the tx fails
            else {
                revert InvalidAggregatorValue();
            }
        }
        // Decimals adjustment is always 10 on Redstone
        return price * 10 ** 10;
    }
}

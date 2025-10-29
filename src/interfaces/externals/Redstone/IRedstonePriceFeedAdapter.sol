// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRedstonePriceFeedAdapter {
    function convertDecimals(bytes32, uint256 valueFromRedstonePayload) external view returns (uint256);
    function extractTimestampsAndAssertAllAreEqual() external pure returns (uint256 extractedTimestamp);
    function getAuthorisedSignerIndex(address signerAddress) external view returns (uint8);
    function getBlockTimestampFromLatestUpdate(bytes32 dataFeedId) external view returns (uint256 blockTimestamp);
    function getDataFeedIdForAsset(address asset) external view returns (bytes32);
    function getDataTimestampFromLatestUpdate(bytes32 dataFeedId) external view returns (uint256 lastDataTimestamp);
    function getLastUpdateDetails(bytes32 dataFeedId) external view returns (uint256 lastDataTimestamp, uint256 lastBlockTimestamp, uint256 lastValue);
    function getLastUpdateDetailsUnsafe(bytes32 dataFeedId) external view returns (uint256 lastDataTimestamp, uint256 lastBlockTimestamp, uint256 lastValue);
    function getUnderlyingAsset(address gToken) external view returns (address);
    function getUnderlyingPrice(address gToken) external view returns (uint256);
    function getUniqueSignersThreshold() external view returns (uint8);
    function getValueForDataFeed(bytes32 dataFeedId) external view returns (uint256 dataFeedValue);
    function priceOf(address asset) external view returns (uint256);
    function priceOfETH() external view returns (uint256);
    function validateTimestamp(uint256 receivedTimestampMilliseconds) external view;
}

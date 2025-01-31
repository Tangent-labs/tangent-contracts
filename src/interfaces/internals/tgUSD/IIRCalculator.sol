// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct IRParams {
    uint128 sigma;
    uint128 r0;
    uint256 irStartPrice;
}

struct RCParams {
    /// @dev Amount of distincts reward cut steps.
    uint16 stepAmount;
    /// @dev Percentage minimum of the reward cut.
    uint32 startCutPercentage;
    /// @dev Percentage maximum of the reward cut.
    uint32 endCutPercentage;
    /// @dev Price of tgUSD on which the reward cut starts to increase.
    uint88 startCutPrice;
    /// @dev Price of tgUSD on which the reward cut is at its maximum
    uint88 endCutPrice;
}
interface IIRCalculator {
    function setUpMarketRewards(address market, IRParams calldata _irParam, RCParams calldata _rcParam) external;
    function simulateIR(uint256 tgUSDPrice, uint256 irStartPrice, uint256 sigma, uint256 r0) external view returns (uint256);
    function computeIRForMarket(address market) external view returns (uint256);
    function simulateRC(
        uint256 tgUSDPrice,
        uint16 stepAmount,
        uint32 startCutPercentage,
        uint32 endCutPercetange,
        uint88 startCutPrice,
        uint88 endCutPrice
    ) external pure returns (uint256);
    function computeRCForMarket(address market) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IIrCalculator {
    function simulateIR(uint256 tgUSDPrice, uint256 irStartPrice, uint256 sigma, uint256 r0) external pure returns (uint256);
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

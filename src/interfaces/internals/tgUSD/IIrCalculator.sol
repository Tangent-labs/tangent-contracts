// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IIrCalculator {
    function simulateIR(uint256 tgUSDPrice, uint256 sigma, uint256 r0) external pure returns (uint256);
    function computeIRForMarket(address market) external view returns (uint256);
    function simulateRC(uint256 tgUSDPrice, uint64 cutAtOneDollar, uint64 stepAmount, uint128 fullCutPrice) external pure returns (uint256);
    function computeRCForMarket(address market) external view returns (uint256);
}

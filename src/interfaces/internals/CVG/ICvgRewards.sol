// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICycleProcessor {
    function cycleProcess(uint256 stepAmount, address[] memory sdtStakings) external;
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function transferTokens(address[] memory tokens, address receiver) external;
}

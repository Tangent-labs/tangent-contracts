// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtIR {
    function checkpointIR() external;
    function positionDebt(address account) external returns (uint256);
}

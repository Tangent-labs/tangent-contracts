// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtIR {
    function totalDebt() external view returns (uint256);
    function positionDebt(address account) external view returns (uint256);

    function checkpointIR() external;
}

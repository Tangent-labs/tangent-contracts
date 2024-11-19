// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtIR {
    function mintPendingInterests() external returns (uint256);
}

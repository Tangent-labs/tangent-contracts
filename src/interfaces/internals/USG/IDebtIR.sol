// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIRCalculator} from "./IIRCalculator.sol";

interface IDebtIR {
    function maxMarketDebt() external view returns (uint256);
    function irCalculator() external view returns (IIRCalculator);
    function minimumLoan() external view returns (uint256);
    function userDebtShares(address user) external view returns (uint256);
    function totalDebtShares() external view returns (uint256);
    function badDebt() external view returns (uint256);
}

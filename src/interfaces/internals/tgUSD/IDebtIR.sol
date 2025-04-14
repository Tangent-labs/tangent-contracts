// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIRCalculator} from "./IIRCalculator.sol";

interface IDebtIR {
    function totalDebt() external view returns (uint256);
    function positionDebt(address account) external view returns (uint256);
    function maxMarketDebt() external view returns (uint256);
    function irCalculator() external view returns (IIRCalculator);
    function minimumLoan() external view returns (uint256);

    function checkpointIR() external;
}

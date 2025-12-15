// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICollateral} from "./ICollateral.sol";
import {IDebtIR} from "./IDebtIR.sol";
interface IMarketViewer {
    function totalDebt(IDebtIR market) external view returns (uint256);
    function pendingInterests(IDebtIR user) external view returns (uint256);

    function userDebt(IDebtIR market, address user) external view returns (uint256);
    function positionValue(ICollateral market, address user) external view returns (uint256);
    function maxBorrowable(ICollateral market, address user) external view returns (uint256);
    function healthRatio(address market, address user) external view returns (uint256);
}

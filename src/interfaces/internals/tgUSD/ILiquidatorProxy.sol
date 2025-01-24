// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILiquidatorProxy {
    function callLiquidate(address liquidator, bytes calldata routerCall) external;
}

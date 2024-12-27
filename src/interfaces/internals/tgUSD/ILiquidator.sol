// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILiquidator {
    function liquidate(bytes calldata routerCall) external;
}

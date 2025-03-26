// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ILiquidatorProxy {
    function callLiquidate(address liquidator, address receiver, IERC20 assetToLiquidate, uint256 minTgUSDReceived, bytes calldata routerCall) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ZapStruct} from "../ICommonStruct.sol";

interface IZappingProxy {
    function zapProxy(IERC20 tokenIn, IERC20 tokenOut, uint256 minAmountOut, address receiver, ZapStruct calldata routerCall) external payable returns (uint256);
}

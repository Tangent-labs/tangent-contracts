// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUSG, IERC20} from "../../src/interfaces/internals/USG/IUSG.sol";

contract MockRouter {
    using SafeERC20 for IERC20;
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function swap(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, address receiver, uint256 amountOut) external payable {
        if (address(tokenIn) != CHAIN_COIN) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        }
        tokenOut.safeTransfer(receiver, amountOut);
    }
}

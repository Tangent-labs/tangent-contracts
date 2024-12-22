// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {ITgUSD, IERC20} from "../../../src/interfaces/internals/tgUSD/ITgUSD.sol";
import {Test} from "forge-std/Test.sol";

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract MockEnsoRouter is StdCheats, StdUtils, Test {
    function routeSingle(address tokenIn, uint256 amountIn, bytes32[] memory commands, bytes[] memory state) external payable returns (bytes[] memory returnData) {
        address tokenOut = bytes32ToAddress(commands[0]);
        address payable mockedLP = payable(bytes32ToAddress(commands[1]));
        address receiver = bytes32ToAddress(commands[2]);
        address zapper = bytes32ToAddress(commands[3]);
        uint256 amountOut = uint256(commands[4]);

        if (tokenIn == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            mockedLP.transfer(amountIn);
        } else {
            IERC20(tokenIn).transferFrom(zapper, mockedLP, amountIn);
        }
        deal(address(tokenOut), receiver, amountOut + IERC20(tokenOut).balanceOf(receiver));

        bytes[] memory data = new bytes[](0);
        return data;
    }

    function bytes32ToAddress(bytes32 data) internal pure returns (address) {
        return address(uint160(uint256(data)));
    }
}

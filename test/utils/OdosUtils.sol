// SPDX-License-Identifier: MIT
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {LowLevel} from "./LowLevel.sol";

contract OdosUtils is Test, LowLevel {
    function getDataCallForOdosSwap(uint256 amountIn, IERC20 tokenIn, uint256 proportion, IERC20 tokenOut, address user, address receiver) public returns (bytes memory) {
        return _getDataForOdosSwapCall(amountIn, tokenIn, proportion, tokenOut, user, receiver);
    }

    function getDataForOdosSwapCall(uint256 amountIn, IERC20 tokenIn, uint256 proportion, IERC20 tokenOut, address user) public returns (bytes memory) {
        return _getDataForOdosSwapCall(amountIn, tokenIn, proportion, tokenOut, user, user);
    }

    function _getDataForOdosSwapCall(uint256 amountIn, IERC20 tokenIn, uint256 proportion, IERC20 tokenOut, address user, address receiver) internal returns (bytes memory) {
        string[] memory inputs = new string[](8);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/getDataForSwap.mjs";
        inputs[2] = vm.toString(amountIn);
        inputs[3] = vm.toString(address(tokenIn));
        inputs[4] = vm.toString(uint256(proportion));
        inputs[5] = vm.toString(address(tokenOut));
        inputs[6] = vm.toString(user);
        inputs[7] = vm.toString(receiver);

        return vm.ffi(inputs);
    }

    function getQuoteOdos(uint256 amountIn, IERC20 tokenIn, IERC20 tokenOut, address user) public returns (uint256) {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/getQuote.mjs";
        inputs[2] = vm.toString(amountIn);
        inputs[3] = vm.toString(address(tokenIn));
        inputs[4] = vm.toString(address(tokenOut));
        inputs[5] = vm.toString(user);

        return stringToUint(string(vm.ffi(inputs)));
    }
}

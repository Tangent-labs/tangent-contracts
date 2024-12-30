// SPDX-License-Identifier: MIT
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IEnsoRouter} from "../../src/interfaces/externals/Aggregators/IEnsoRouter.sol";
import {LowLevel} from "./LowLevel.sol";

contract EnsoUtils is Test, LowLevel {
    function getZapCall(address fromAddress, address receiver, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut) public returns (bytes memory) {
        string[] memory inputs = new string[](8);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/enso/getRouteData.mjs";
        inputs[2] = vm.toString(fromAddress);
        inputs[3] = vm.toString(receiver);
        inputs[4] = vm.toString(address(tokenIn));
        inputs[5] = vm.toString(amountIn);
        inputs[6] = vm.toString(address(tokenOut));
        inputs[7] = vm.toString(minAmountOut);

        return vm.ffi(inputs);
    }

    function getQuote(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 slippageMax) public returns (uint256) {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/enso/getQuote.mjs";
        inputs[2] = vm.toString(address(tokenIn));
        inputs[3] = vm.toString(amountIn);
        inputs[4] = vm.toString(address(tokenOut));
        uint256 quote = stringToUint(string(vm.ffi(inputs)));
        return quote - (quote * slippageMax) / 100;
    }

    function getZapCallMocked(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        address mockedLP,
        address receiver,
        address zapper,
        uint256 amountOut
    ) external pure returns (bytes memory) {
        bytes32[] memory commands = new bytes32[](5);
        commands[0] = addressToBytes32(tokenOut);
        commands[1] = addressToBytes32(mockedLP);
        commands[2] = addressToBytes32(receiver);
        commands[3] = addressToBytes32(zapper);
        commands[4] = bytes32(amountOut);

        bytes[] memory state = new bytes[](0);

        return abi.encodeWithSelector(IEnsoRouter.routeSingle.selector, tokenIn, amountIn, commands, state);
    }
}

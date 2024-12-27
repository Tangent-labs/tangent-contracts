// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LowLevel} from "./LowLevel.sol";
contract IRCalculationFFI is Test, LowLevel {
    function getIRFFI(uint256 tgUSDPrice, uint256 irStartPrice, uint256 sigma, uint256 r0) external returns (uint256) {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/computeIR.mjs";
        inputs[2] = vm.toString(tgUSDPrice);
        inputs[3] = vm.toString(irStartPrice);
        inputs[4] = vm.toString(sigma);
        inputs[5] = vm.toString(r0);

        return stringToUint(string(vm.ffi(inputs)));
    }
}

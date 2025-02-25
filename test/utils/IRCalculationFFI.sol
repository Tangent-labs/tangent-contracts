// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LowLevel} from "./LowLevel.sol";
contract IRCalculationFFI is Test, LowLevel {
    function getIRFFI(uint256 tgUSDPrice, uint32 rMin, uint32 rMax, uint32 pMin, uint32 pInf, uint32 pMax, uint32 a1, uint32 a2, uint32 k) external returns (uint256) {
        string[] memory inputs = new string[](11);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/irComputation/printIR.mjs";
        inputs[2] = vm.toString(uint256(tgUSDPrice));
        inputs[3] = vm.toString(uint256(rMin));
        inputs[4] = vm.toString(uint256(rMax));
        inputs[5] = vm.toString(uint256(pMin));
        inputs[6] = vm.toString(uint256(pInf));
        inputs[7] = vm.toString(uint256(pMax));
        inputs[8] = vm.toString(uint256(a1));
        inputs[9] = vm.toString(uint256(a2));
        inputs[10] = vm.toString(uint256(k));
        return stringToUint(string(vm.ffi(inputs)));
    }
}

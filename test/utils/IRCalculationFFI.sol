// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LowLevel} from "./LowLevel.sol";
contract IRCalculationFFI is Test, LowLevel {
    function getIRFFI(uint256 tgUSDPrice, bool isHEC, uint24 rMin, uint32 rMax, uint32 pMin, uint32 pInf, uint32 pMax, uint32 a1, uint32 a2, uint32 k) external returns (uint256) {
        string[] memory inputs = new string[](12);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/irComputation/printIR.mjs";
        inputs[2] = vm.toString(uint256(tgUSDPrice));
        inputs[3] = vm.toString(isHEC);
        inputs[4] = vm.toString(uint256(rMin));
        inputs[5] = vm.toString(uint256(rMax));
        inputs[6] = vm.toString(uint256(pMin));
        inputs[7] = vm.toString(uint256(pInf));
        inputs[8] = vm.toString(uint256(pMax));
        inputs[9] = vm.toString(uint256(a1));
        inputs[10] = vm.toString(uint256(a2));
        inputs[11] = vm.toString(uint256(k));
        return stringToUint(string(vm.ffi(inputs)));
    }

    function getIndexFFI(uint256 oldIndex, uint256 ir, uint256 timeDelta) external returns (uint256) {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/irComputation/printIndex.mjs";
        inputs[2] = vm.toString(oldIndex);
        inputs[3] = vm.toString(ir);
        inputs[4] = vm.toString(timeDelta);
        return stringToUint(string(vm.ffi(inputs)));
    }
}

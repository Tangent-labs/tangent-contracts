// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../../../src/tgUSD/Utilities/IRCalculator.sol";
contract ExpIRF is ConvexCurveContext {
    function getIRFFI(uint256 tgUSDPrice, uint256 sigma, uint256 r0) internal returns (uint256) {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/computeIR.mjs";
        inputs[2] = vm.toString(tgUSDPrice);
        inputs[3] = vm.toString(sigma);
        inputs[4] = vm.toString(r0);

        return stringToUint(string(vm.ffi(inputs)));
    }

    // function test_simple() external {
    //     uint256 tgUSDPrice = 999500000000000000;
    //     uint256 sigma = 2750000000000000;
    //     uint256 r0 = 5000000000000000000;

    //     uint256 expected = getIRFFI(tgUSDPrice, sigma, r0);
    //     uint256 calculated = irCalculator.computeIR(tgUSDPrice, sigma, r0);

    //     assertApproxEqRel(expected, calculated, 1e8);
    // }

    function test_toto(uint256 tgUSDPrice, uint256 sigma, uint256 r0) external {
        tgUSDPrice = bound(tgUSDPrice, 880000000000000000, 1 ether);
        sigma = 2750000000000000;
        r0 = 5 ether;

        uint256 expected = getIRFFI(tgUSDPrice, sigma, r0);
        console.log("expected", expected);
        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, sigma, r0);
        console.log("calculated", calculated);

        assertApproxEqRel(expected, calculated, 1e8);
    }
}

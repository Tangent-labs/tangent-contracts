// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../../../src/tgUSD/Utilities/IRCalculator.sol";
import "../../../utils/IRCalculationFFI.sol";
contract ExpIRFormulaComputation is ConvexCurveContext {
    uint256 constant _2_DOLLARS = 2 ether;
    uint256 constant _1_DOLLARS = 1 ether;
    uint256 constant _99_CENTS = 990000000000000000;
    uint256 constant _88_CENTS = 880000000000000000;

    uint256 constant _0_275_PERCENT = 2750000000000000;
    uint256 constant _5_PERCENT = 5 ether;

    function test_fuzzing_with_bounds(uint256 tgUSDPrice, uint256 irStartPrice, uint256 sigma, uint256 r0) external {
        IRCalculationFFI irFFI = new IRCalculationFFI();
        tgUSDPrice = bound(tgUSDPrice, _88_CENTS, _2_DOLLARS);
        irStartPrice = bound(irStartPrice, _99_CENTS, _1_DOLLARS);
        sigma = _0_275_PERCENT;
        r0 = _5_PERCENT;

        uint256 expected = irFFI.getIRFFI(tgUSDPrice, irStartPrice, sigma, r0);

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, irStartPrice, sigma, r0);

        assertApproxEqRel(expected, calculated, 1e8);
    }
}

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

    IRCalculationFFI irFFI = new IRCalculationFFI();

    function test_ir_without_pInf() external {
        uint256 tgUSDPrice = 9900 * 10 ** 14;
        uint32 rMin = 4_000;
        uint32 rMax = 400_000;
        uint32 pMin = 98_000;
        uint32 pMax = 100_000;
        uint32 pInf = 0;
        uint32 a1 = 2;
        uint32 a2 = 2;
        uint32 k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 1030000000000000000, "103% IR with these conditions");
    }

    function test_ir_stable_price_lower_than_pMin() external {
        uint256 tgUSDPrice = 9800 * 10 ** 14;
        uint32 rMin = 4_000;
        uint32 rMax = 400_000;
        uint32 pMin = 99_000;
        uint32 pMax = 100_000;
        uint32 pInf = 0;
        uint32 a1 = 2;
        uint32 a2 = 2;
        uint32 k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 4000000000000000000, "Equals to the maximum rate, 400%");
    }

    function test_ir_stable_price_higher_than_pMax() external {
        uint256 tgUSDPrice = 101 * 10 ** 16;
        uint32 rMin = 4_000;
        uint32 rMax = 400_000;
        uint32 pMin = 99_000;
        uint32 pMax = 100_000;
        uint32 pInf = 0;
        uint32 a1 = 2;
        uint32 a2 = 2;
        uint32 k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 40000000000000000, "Equals to the maximum rate, 4%");
    }

    function test_fuzzing_with_bounds(uint256 tgUSDPrice, uint32 rMin, uint32 rMax, uint32 pMin, uint32 pInf, uint32 pMax, uint32 a1, uint32 a2, uint32 k) external {
        tgUSDPrice = bound(tgUSDPrice, _88_CENTS, _2_DOLLARS);

        rMin = uint32(bound(uint256(rMin), 0, 1_000_000));
        rMax = uint32(bound(uint256(rMax), rMin, 2_000_000));

        pMin = uint32(bound(uint256(pMin), 0, 1_000_000));
        pMax = uint32(bound(uint256(pMax), uint256(pMin), 2_000_000));
        pInf = uint32(bound(uint256(pInf), pMin, pMax));

        a1 = uint32(bound(uint256(a1), 0, 99_000));
        a2 = uint32(bound(uint256(a2), 0, 99_000));

        k = uint32(bound(k, 0, 99_000));

        uint256 expected = irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pMax, pInf, a1, a2, k);

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertApproxEqRel(expected, calculated, 1e8);
    }
}

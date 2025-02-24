// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../../../src/tgUSD/Utilities/IRCalculator.sol";
import "../../../utils/IRCalculationFFI.sol";
contract ExpIRFormulaComputation is ConvexCurveContext {
    uint256 constant _2_DOLLARS = 2 ether;
    uint256 constant _88_CENTS = 880000000000000000;

    IRCalculationFFI irFFI = new IRCalculationFFI();

    uint256 tgUSDPrice;
    uint32 rMin;
    uint32 rMax;
    uint32 pMin;
    uint32 pInf;
    uint32 pMax;
    uint32 a1;
    uint32 a2;
    uint32 k;

    function test_from_fuzzing1() external {
        tgUSDPrice = 909795958679092860;
        rMin = 26;
        rMax = 29;
        pMin = 17;
        pInf = 148686;
        pMax = 1999994;
        a1 = 2;
        a2 = 4;
        k = 10109;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            90 * 1e14 //0.9%
        );
    }

    function test_from_fuzzing2() external {
        tgUSDPrice = 1120000000000002248;
        rMin = 0;
        rMax = 16111;
        pMin = 14446;
        pInf = 1973764;
        pMax = 1988068;
        a1 = 7507;
        a2 = 4071;
        k = 27580;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            90 * 1e14 //0.9%
        );
    }

    function test_from_fuzzing3() external {
        tgUSDPrice = 1495288770417798419;
        rMin = 20937;
        rMax = 1807457;
        pMin = 1;
        pInf = 300874;
        pMax = 598849;
        a1 = 3;
        a2 = 57627;
        k = 20441;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            90 * 1e14 //0.9%
        );
    }

    function test_from_fuzzing4() external {
        tgUSDPrice = 202806;
        rMin = 48396;
        rMax = 1955213;
        pMin = 0;
        pInf = 18851;
        pMax = 202707;
        a1 = 6912;
        a2 = 7231;
        k = 8;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            90 * 1e14 //0.9%
        );
    }

    function test_from_fuzzing5() external {
        tgUSDPrice = 4746;
        rMin = 3512;
        rMax = 10556;
        pMin = 0;
        pInf = 10223;
        pMax = 10671;
        a1 = 16041;
        a2 = 5597;
        k = 5062;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            90 * 1e14 //0.9%
        );
    }

    function test_ir_without_pInf() external {
        tgUSDPrice = 9900 * 10 ** 14;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 980_000;
        pInf = 0;
        pMax = 1_000_000;
        a1 = 2;
        a2 = 2;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 1030000000000000000, "103% IR with these conditions");
    }

    function test_ir_stable_price_lower_than_pMin() external {
        tgUSDPrice = 98 * 10 ** 16;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 990_000;
        pMax = 1_000_000;
        pInf = 0;
        a1 = 2;
        a2 = 2;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 4000000000000000000, "Equals to the maximum rate, 400%");
    }

    function test_ir_stable_price_higher_than_pMax() external {
        tgUSDPrice = 101 * 10 ** 16;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 990_000;
        pMax = 1_000_000;
        pInf = 0;
        a1 = 2;
        a2 = 2;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 40000000000000000, "Equals to the maximum rate, 4%");
    }

    function test_fuzzing_with_bounds(uint256 tgUSDPrice_, uint32 rMin_, uint32 rMax_, uint32 pMin_, uint32 pInf_, uint32 pMax_, uint32 a1_, uint32 a2_, uint32 k_) external {
        rMin_ = uint32(bound(uint256(rMin_), 0, 1_000_000));
        rMax_ = uint32(bound(uint256(rMax_), rMin_, 2_000_000));

        pMin_ = uint32(bound(uint256(pMin_), 0, 1_000_000));
        pMax_ = uint32(bound(uint256(pMax_), uint256(pMin_), 2_000_000));
        pInf_ = uint32(bound(uint256(pInf_), pMin_, pMax_));

        tgUSDPrice_ = bound(tgUSDPrice_, pMin_ == 0 ? 0 : pMin_ - 1, pMax_ + 100);

        a1_ = uint32(bound(uint256(a1_), 0, 99_000));
        a2_ = uint32(bound(uint256(a2_), 0, 99_000));

        k_ = uint32(bound(k_, 0, 99_000));

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice_, rMin_, rMax_, pMin_, pInf_, pMax_, a1_, a2_, k_),
            irCalculator.simulateIR(tgUSDPrice_, IRParams({rMin: rMin_, rMax: rMax_, pMin: pMin_, pInf: pInf_, pMax: pMax_, a1: a1_, a2: a2_, k: k_})),
            50 * 1e14 //0.9%
        );
    }
}

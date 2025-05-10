// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../../src/tgUSD/Utilities/IRCalculator.sol";
import "../../utils/IRCalculationFFI.sol";
contract ExpIRFormulaComputation is MarketDeploymentContext {
    uint256 constant _2_DOLLARS = 2 ether;
    uint256 constant _88_CENTS = 880000000000000000;

    IRCalculationFFI irFFI = new IRCalculationFFI();

    uint256 tgUSDPrice;
    uint24 rMin;
    uint32 rMax;
    uint32 pMin;
    uint32 pInf;
    uint32 pMax;
    uint32 a1;
    uint32 a2;
    uint32 k;

    function test_IR_from_fuzzing1() external {
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
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing2() external {
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
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing3() external {
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
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing4() external {
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
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing5() external {
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
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing6() external {
        tgUSDPrice = 1026721955184017480;
        rMin = 0;
        rMax = 1538949;
        pMin = 980874;
        pInf = 1022223;
        pMax = 1027337;
        a1 = 2929;
        a2 = 6911;
        k = 6911;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_from_fuzzing7() external {
        tgUSDPrice = 1185971000000000099;
        rMin = 13898;
        rMax = 876633;
        pMin = 57;
        pInf = 90875;
        pMax = 1185971;
        a1 = 31723;
        a2 = 0;
        k = 92;

        assertApproxEqRel(
            irFFI.getIRFFI(tgUSDPrice, false, rMin, rMax, pMin, pInf, pMax, a1, a2, k),
            irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k})),
            10 * 1e14 //0.1%
        );
    }

    function test_IR_without_pInf() external {
        // 0.99$
        tgUSDPrice = 99 * 10 ** 16;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 980_000;
        pInf = 0;
        pMax = 1_000_000;
        a1 = 2_000;
        a2 = 2_000;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 1030000000000000000, "103% IR with these conditions");
    }

    function test_IR_stable_price_lower_than_pMin() external {
        tgUSDPrice = 98 * 10 ** 16;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 990_000;
        pMax = 1_000_000;
        pInf = 0;
        a1 = 2;
        a2 = 2;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 4000000000000000000, "Equals to the maximum rate, 400%");
    }

    function test_IR_stable_price_higher_than_pMax() external {
        tgUSDPrice = 101 * 10 ** 16;
        rMin = 4_000;
        rMax = 400_000;
        pMin = 990_000;
        pMax = 1_000_000;
        pInf = 0;
        a1 = 2;
        a2 = 2;
        k = 0;

        uint256 calculated = irCalculator.simulateIR(tgUSDPrice, IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k}));

        assertEq(calculated, 40000000000000000, "Equals to the maximum rate, 4%");
    }

    struct DoubleAmount {
        uint256 price;
        uint256 ir;
    }

    function test_IR_from_excel() external {
        rMin = 4_000; // 4%
        rMax = 400_000; // 400%
        pMin = 980_000; // 0.98$
        pMax = 1_000_000; // 1$
        pInf = 999_500; // 0.9995$
        a1 = 2_000; // 2
        a2 = 2_500; // 2.5
        k = 250;

        DoubleAmount[] memory testResults = new DoubleAmount[](5);
        testResults[0] = DoubleAmount(10 ** 18, 4 * 10 ** 16);
        testResults[1] = DoubleAmount(9_995 * 10 ** 14, 41 * 10 ** 15); // 0.9995$ => 4.10%
        testResults[2] = DoubleAmount(9_990 * 10 ** 14, 449 * 10 ** 14); // 0.9990$ => 4.49%
        testResults[3] = DoubleAmount(9_935 * 10 ** 14, 4175 * 10 ** 14); // 0.9935$ => 41.75%
        testResults[4] = DoubleAmount(9_840 * 10 ** 14, 25687 * 10 ** 14); // 0.9840$ => 256.87%

        IRParams memory params = IRParams({isHEC: false, rMin: rMin, rMax: rMax, pMin: pMin, pMax: pMax, pInf: pInf, a1: a1, a2: a2, k: k});

        for (uint256 i; i < testResults.length; i++) {
            assertApproxEqRel(
                testResults[i].ir,
                irCalculator.simulateIR(testResults[i].price, params),
                40 * 1e13 //0.01%
            );
        }
    }

    function test_IR_fuzzing_with_big_bounds(
        uint256 tgUSDPrice_,
        bool isHEC,
        uint24 rMin_,
        uint32 rMax_,
        uint32 pMin_,
        uint32 pInf_,
        uint32 pMax_,
        uint32 a1_,
        uint32 a2_,
        uint32 k_
    ) external {
        rMin_ = uint24(bound(uint256(rMin_), 0, 1_000_000));
        rMax_ = uint32(bound(uint256(rMax_), rMin_, 2_000_000));

        pMin_ = uint32(bound(uint256(pMin_), 0, 1_000_000));
        pMax_ = uint32(bound(uint256(pMax_), uint256(pMin_) + 1, 2_000_000));
        pInf_ = uint32(bound(uint256(pInf_), pMin_, pMax_));

        tgUSDPrice_ = bound(tgUSDPrice_, pMin_ == 0 ? 0 : uint256(pMin_) * 10 ** 12 - 1, uint256(pMax_) * 10 ** 12 + 100);

        a1_ = uint32(bound(uint256(a1_), 0, 99_000));
        a2_ = uint32(bound(uint256(a2_), 0, 99_000));

        k_ = uint32(bound(k_, 0, 99_000));

        uint256 expected = irFFI.getIRFFI(tgUSDPrice_, isHEC, rMin_, rMax_, pMin_, pInf_, pMax_, a1_, a2_, k_);
        uint256 calculated = irCalculator.simulateIR(
            tgUSDPrice_,
            IRParams({isHEC: isHEC, rMin: rMin_, rMax: rMax_, pMin: pMin_, pInf: pInf_, pMax: pMax_, a1: a1_, a2: a2_, k: k_})
        );

        if (expected <= 10_000) {
            assertApproxEqAbs(expected, calculated, 1); // 1 wei delta
        } else {
            assertApproxEqRel(expected, calculated, 10 * 1e13); //0.01% delta
        }
    }
    function test_IR_fuzzing_with_small_bounds(
        uint256 tgUSDPrice_,
        bool isHEC,
        uint24 rMin_,
        uint32 rMax_,
        uint32 pMin_,
        uint32 pInf_,
        uint32 pMax_,
        uint32 a1_,
        uint32 a2_,
        uint32 k_
    ) external {
        rMin_ = uint24(bound(uint256(rMin_), 0, 50_000));
        rMax_ = uint32(bound(uint256(rMax_), rMin_, 2_000_000));

        pMin_ = uint32(bound(uint256(pMin_), 970_000, 990_000));
        pMax_ = uint32(bound(uint256(pMax_), uint256(pMin_) + 1, 2_000_000));
        pInf_ = uint32(bound(uint256(pInf_), pMin_, pMax_));

        tgUSDPrice_ = bound(tgUSDPrice_, pMin_ == 0 ? 0 : uint256(pMin_) * 10 ** 12 - 1, uint256(pMax_) * 10 ** 12 + 100);

        a1_ = uint32(bound(uint256(a1_), 0, 990_000));
        a2_ = uint32(bound(uint256(a2_), 0, 990_000));

        k_ = uint32(bound(k_, 0, 99_000));

        uint256 expected = irFFI.getIRFFI(tgUSDPrice_, isHEC, rMin_, rMax_, pMin_, pInf_, pMax_, a1_, a2_, k_);
        uint256 calculated = irCalculator.simulateIR(
            tgUSDPrice_,
            IRParams({isHEC: isHEC, rMin: rMin_, rMax: rMax_, pMin: pMin_, pInf: pInf_, pMax: pMax_, a1: a1_, a2: a2_, k: k_})
        );

        if (expected <= 10_000) {
            assertApproxEqAbs(expected, calculated, 1); // 1 wei delta
        } else {
            assertApproxEqRel(expected, calculated, 10 * 1e13); //0.01% delta
        }
    }
}

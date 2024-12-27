// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract RewardCutFormulaComputation is ConvexCurveContext {
    uint256 constant _2_DOLLARS = 2 ether;
    uint256 constant _1_DOLLARS = 1 ether;

    uint256 constant _99_5_CENTS = 995000000000000000;
    uint256 constant _99_CENTS = 990000000000000000;
    uint256 constant _88_CENTS = 880000000000000000;

    uint256 constant _50_CENTS = 880000000000000000;

    uint256 constant _0_PERCENT = 0;
    uint256 constant _50_PERCENT = 50_000;
    uint256 constant _100_PERCENT = 100_000;

    function test_rewardCut_step_greater_than_3_in_a_step() external {
        uint256 rcCalculated = irCalculator.simulateRC(994000000000000000, uint16(5), uint32(50_000), uint32(100_000), uint88(996000000000000000), uint88(991000000000000000));
        assertEq(rcCalculated, 83_333);
    }

    function test_rewardCut_price_under_endCutPrice() external {
        uint256 rcCalculated = irCalculator.simulateRC(994000000000000000, uint16(5), uint32(50_000), uint32(100_000), uint88(998000000000000000), uint88(995000000000000000));
        assertEq(rcCalculated, 100_000);
    }

    function test_rewardCut_price_over_startCutPrice() external {
        uint256 rcCalculated = irCalculator.simulateRC(998000000000000000, uint16(5), uint32(50_000), uint32(100_000), uint88(99800000000000000), uint88(995000000000000000));
        assertEq(rcCalculated, 50_000);
    }

    function test_rewardCut_price_with_big_steps() external {
        uint256 rcCalculated = irCalculator.simulateRC(993500000000000000, uint16(100), uint32(50_000), uint32(100_000), uint88(996000000000000000), uint88(991000000000000000));
        assertEq(rcCalculated, 75510);
    }

    function test_rewardCut_with_one_step() external {
        uint256 rcCalculated = irCalculator.simulateRC(993500000000000000, uint16(1), uint32(12_000), uint32(100_000), uint88(996000000000000000), uint88(991000000000000000));
        assertEq(rcCalculated, 12_000);
    }

    function test_rewardCut_with_two_steps() external {
        uint256 rcCalculated = irCalculator.simulateRC(996000000000000000, uint16(2), uint32(12_000), uint32(50_000), uint88(996000000000000000), uint88(991000000000000000));
        assertEq(rcCalculated, 12_000);

        rcCalculated = irCalculator.simulateRC(995000000000000000, uint16(2), uint32(12_000), uint32(50_000), uint88(996000000000000000), uint88(991000000000000000));
        assertEq(rcCalculated, 50_000);
    }
}

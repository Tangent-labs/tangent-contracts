// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract RewardCutFormulaComputation is MarketDeploymentContext {
    uint256 constant _2_DOLLARS = 2 ether;
    uint256 constant _1_DOLLARS = 1 ether;

    uint256 constant _99_5_CENTS = 995000000000000000;
    uint256 constant _99_CENTS = 990000000000000000;
    uint256 constant _88_CENTS = 880000000000000000;

    uint256 constant _50_CENTS = 880000000000000000;

    uint256 constant _0_PERCENT = 0;
    uint256 constant _50_PERCENT = 50_000;
    uint256 constant _100_PERCENT = 100_000;

    function test_rewardCut_step_greater_than_3_in_a_step() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(994000000000000000, RCParams(0, uint16(5), uint32(50_000), uint32(100_000), uint80(996_000), uint80(991_000)));
        assertEq(rcCalculated, 83_333);
    }

    function test_rewardCut_price_under_endCutPrice() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(994000000000000000, RCParams(0, uint16(5), uint32(50_000), uint32(100_000), uint80(998_000), uint80(995_000)));
        assertEq(rcCalculated, 100_000);
    }

    function test_rewardCut_price_over_startCutPrice() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(998000000000000000, RCParams(0, uint16(5), uint32(50_000), uint32(100_000), uint80(998_000), uint80(995_000)));
        assertEq(rcCalculated, 50_000);
    }

    function test_rewardCut_price_with_big_steps() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(993500000000000000, RCParams(0, uint16(100), uint32(50_000), uint32(100_000), uint80(996_000), uint80(991_000)));
        assertEq(rcCalculated, 75510);
    }

    function test_rewardCut_with_one_step() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(993500000000000000, RCParams(0, uint16(1), uint32(12_000), uint32(100_000), uint80(996_000), uint80(991_000)));
        assertEq(rcCalculated, 12_000);
    }

    function test_rewardCut_with_two_steps() external view {
        uint256 rcCalculated = rewardAccumulator.simulateRC(996000000000000000, RCParams(0, uint16(2), uint32(12_000), uint32(50_000), uint80(996_000), uint80(991_000)));
        assertEq(rcCalculated, 12_000);

        rcCalculated = rewardAccumulator.simulateRC(995000000000000000, RCParams(0, uint16(2), uint32(12_000), uint32(50_000), uint80(996_000), uint80(991_000)));
        assertEq(rcCalculated, 50_000);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../contexts/MarketDeploymentContext.sol";
import {ConvexBoostsUI, ConvexBoostsUIOut, GaugeBoost} from "../../../src/chainview/USG/ui/ConvexBoostsUI.cv.sol";

contract ConvexBoostsUIChainviewTest is MarketDeploymentContext {
    function setUp() public {
        vm.createSelectFork("mainnet", 24749020);
    }

    function test_convexBoosts_ui_returns() public {
        uint256[] memory pids = new uint256[](2);
        pids[0] = 541;
        pids[1] = 542;
        // pids[2] = 377;
        // pids[3] = 425;

        try new ConvexBoostsUI(pids) {} catch (bytes memory reason) {
            ConvexBoostsUIOut memory result = abi.decode(removeFirst4Bytes(reason), (ConvexBoostsUIOut));
            assertTrue(reason.length ==2, "Chainview failed");
            assertTrue(result.fee > 0, "Fee should be positive");
            assertEq(result.gaugeBoosts.length, 2);
            assertEq(result.gaugeBoosts[0].pid, 541);
            assertEq(result.gaugeBoosts[1].pid, 542);
            console.log("Gauge Boosts:");
            for (uint256 i = 0; i < result.gaugeBoosts.length;  i++) {
                GaugeBoost memory boost = result.gaugeBoosts[i];
                assertEq(boost.boost, 5, "PID mismatch");
            }
            // assertEq(result.gaugeBoosts[2].pid, 377);
            // assertEq(result.gaugeBoosts[3].pid, 425);
        }
    }
}

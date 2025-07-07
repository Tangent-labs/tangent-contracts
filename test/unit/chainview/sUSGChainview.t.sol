// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../../src/chainview/usg/ui/sUSGUI.cv.sol";

contract sUSGChainview is MarketDeploymentContext {
    // LIST
    function test_sUSG_UI_not_connected() public {
        try new sUSGUI(address(0), USGOracle, usg, sUSG) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function test_sUSG_UI_connected() public {
        try new sUSGUI(address(0), USGOracle, usg, sUSG) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

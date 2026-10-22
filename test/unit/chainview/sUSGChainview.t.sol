// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../../src/chainview/USG/ui/sUSGUI.cv.sol";

contract sUSGChainview is MarketDeploymentContext {
    function _pegKeepers() internal view returns (address[] memory) {
        address[] memory pks = new address[](2);
        pks[0] = address(pegKeeperUSG_USDC);
        pks[1] = address(pegKeeperUSG_wcrvUSD);
        return pks;
    }

    function test_sUSG_UI_not_connected() public {
        try new sUSGUI(address(0), USGOracle, usg, sUSG, _pegKeepers()) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function test_sUSG_UI_connected() public {
        try new sUSGUI(address(0), USGOracle, usg, sUSG, _pegKeepers()) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

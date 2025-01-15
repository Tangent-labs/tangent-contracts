// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/SgUSDUI.cv.sol";

contract SgUSDChainview is ConvexCurveContext {
    // LIST
    function test_sgUSD_UI_not_connected() public {
        try new SgUSDUI(address(0), oracles[tgUsd], tgUsd, sgUSD) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function test_sgUSD_UI_connected() public {
        try new SgUSDUI(address(0), oracles[tgUsd], tgUsd, sgUSD) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

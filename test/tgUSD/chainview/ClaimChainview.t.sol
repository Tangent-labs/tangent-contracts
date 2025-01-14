// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/ClaimUI.cv.sol";

contract ClaimChainview is ConvexCurveContext {
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.CRVUSD_USDC);
    }

    // LIST
    function test_claimMarket_ui_returns() public {
        address[] memory paramsIn = new address[](1);
        paramsIn[0] = address(market);
        try new ClaimUI(usr1, paramsIn) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

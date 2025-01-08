// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/MarketDetailsUI.cv.sol";

contract MarketDetailsChainview is ConvexCurveContext {
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.CRVUSD_USDC);
    }

    // LIST
    function test_marketDetails_ui_returns() public {
        try new MarketDetailsUI(usr1, address(market)) {} catch (bytes memory reason) {
            console.logBytes(reason);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

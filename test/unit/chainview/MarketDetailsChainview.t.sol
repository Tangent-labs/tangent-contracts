// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/USG/ui/MarketDetailsUI.cv.sol";

contract MarketDetailsChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
    }

    // LIST
    function test_marketDetails_ui_returns() public {
        try new MarketDetailsUI(usr1, address(market), marketViewer, usg) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

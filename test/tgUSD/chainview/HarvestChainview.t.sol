// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/HarvestUI.cv.sol";

contract HarvestChainview is ConvexCurveContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.CRVUSD_USDC);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.PXETH_WETH);
    }

    // LIST
    function test_harvest_ui_returns() public {
        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);



        try new HarvestUI(markets) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

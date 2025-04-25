// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/MarketDeploymentContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/HarvestUI.cv.sol";

contract HarvestChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.WETH_pxETH);
    }

    // LIST
    function test_harvest_ui_returns() public {
        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);
        try new HarvestUI(markets, rewardAccumulator) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

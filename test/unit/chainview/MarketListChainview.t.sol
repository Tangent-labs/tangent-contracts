// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/USG/ui/MarketListUI.cv.sol";

contract MarketListChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.WETH_frxETH);
    }

    // LIST
    function test_marketDetails_ui_returns() public {
        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);

        address[] memory pegKeepers = new address[](2);
        pegKeepers[0] = address(pegKeeperUSG_USDC);
        pegKeepers[1] = address(pegKeeperUSG_wcrvUSD);

        try new MarketListUI(usr1, USGOracle, usg, sUSG, markets, pegKeepers, marketViewer) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

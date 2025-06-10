// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/HarvestUI.cv.sol";

contract HarvestChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;
    ConvexFxnLPMarket public market3;
    MarketNoSociabilization public market4;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.WETH_pxETH, true);
        market3 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        market4 = deployMarketNoSociabilisation(AddrPTPendle.eUSDe_29_05_25);
    }

    // LIST
    function test_harvest_ui_returns() public {
        address[] memory markets = new address[](4);
        markets[0] = address(market1);
        markets[1] = address(market2);
        markets[2] = address(market3);
        markets[3] = address(market4);
        try new HarvestUI(markets, rewardAccumulator) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

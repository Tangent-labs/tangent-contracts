// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/MarketListUI.cv.sol";

contract MarketListChainview is ConvexCurveContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.CRVUSD_USDC);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.FRXETH_WETH);
    }

    // LIST
    function test_marketDetails_ui_returns() public {
        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);
        try new MarketListUI(usr1, tgUSDOracle, tgUSD, sgUSD, markets) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
// ProcessRewardsAndClaimCvxMarket - DepositAndBorrowReverts / ClaimMultiple / ClaimChainview

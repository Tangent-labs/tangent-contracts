// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import {LandingChainView} from "../../../src/chainview/boosters/LandingChainView.cv.sol";

contract LandingChainViewTest is MarketDeploymentContext {
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
    }

    // LIST
    function test_LandingChainView_ui_returns() public {
        try new LandingChainView() {} catch (bytes memory reason) {
            console.logBytes(reason);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

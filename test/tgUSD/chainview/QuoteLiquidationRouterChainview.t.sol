// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import {QuoteLiquidationRouter, CurveQuote, WStableQuote, QuoteLiquidationRouterIn} from "../../../src/chainview/tgUSD/bot/QuoteLiquidationRouter.cv.sol";

contract QuoteLiquidationRouterChainview is ConvexCurveContext {
    uint256 constant ZERO = 0;
    // LIST
    function test_quote_curve_router_chainview_without_wStable() public {
        QuoteLiquidationRouterIn[] memory quoteIn = new QuoteLiquidationRouterIn[](1);
        address[11] memory route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_USDC),
            address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
            address(tgUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
            [ZERO, uint256(1), uint256(1), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        WStableQuote memory wStableQuote = WStableQuote({stablePool: address(0), i: int128(0), j: int128(1), amountIn: 0});

        quoteIn[0] = QuoteLiquidationRouterIn({curveQuote: curveQuote, wStableQuote: wStableQuote});
        try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    // function test_liquidator_curve_router_chainview_with_wStable() public {
    //     QuoteLiquidationRouterIn[] memory quoteIn = new QuoteLiquidationRouterIn[](1);
    //     address[11] memory route = [
    //         address(AddrCurveStableLP.CRVUSD_USDC),
    //         address(AddrCurveStableLP.CRVUSD_USDC),
    //         address(AddrClassicERC20.TOKEN_USDC),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0)
    //     ];
    //     uint256[5][5] memory swapParams = [
    //         [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO]
    //     ];
    //     address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

    //     CurveQuote memory curveQuote = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
    //     WStableQuote memory wStableQuote = WStableQuote({stablePool: address(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD")), i: int128(0), j: int128(1), amountIn: 0});

    //     quoteIn[0] = QuoteLiquidationRouterIn({curveQuote: curveQuote, wStableQuote: wStableQuote});
    //     try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
    //         assertTrue(reason.length > 3, "Chainview failed");
    //     }
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import {QuoteLiquidationRouter, CurveQuote, WStableQuote, QuoteLiquidationRouterIn} from "../../../src/chainview/tgUSD/bot/QuoteLiquidationRouter.cv.sol";

contract QuoteLiquidationRouterChainview is ConvexCurveContext {
    uint256 constant ZERO = 0;

    // QUOTE crvUSD-USDC => USDC => tgUSD-USDC => tgUSD
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
        WStableQuote memory wStableQuote = WStableQuote({stablePool: address(0), i: int128(0), j: int128(1)});

        quoteIn[0] = QuoteLiquidationRouterIn({curveQuote: curveQuote, wStableQuote: wStableQuote});
        try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    // QUOTE crvUSD-USDC => crvUSD => wcrvUSD => tgUSD-wcrvUSD => tgUSD
    function test_liquidator_curve_router_chainview_with_wStable() public {
        address[11] memory route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_CRVUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, uint256(1), uint256(6), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        WStableQuote memory wStableQuote = WStableQuote({stablePool: address(lpDeploymentContext.tgUSDLPs("tgUSD-wcrvUSD")), i: int128(0), j: int128(1)});

        QuoteLiquidationRouterIn[] memory quoteIn = new QuoteLiquidationRouterIn[](1);
        quoteIn[0] = QuoteLiquidationRouterIn({curveQuote: curveQuote, wStableQuote: wStableQuote});
        try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function test_liquidator_curve_router_chainview_multi_quote() public {
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

        CurveQuote memory curveQuote1 = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        WStableQuote memory wStableQuote1 = WStableQuote({stablePool: address(0), i: int128(0), j: int128(1)});

        route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_CRVUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        swapParams = [
            [ZERO, uint256(1), uint256(6), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote2 = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        WStableQuote memory wStableQuote2 = WStableQuote({stablePool: address(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD")), i: int128(0), j: int128(1)});

        QuoteLiquidationRouterIn[] memory quoteIn = new QuoteLiquidationRouterIn[](2);
        quoteIn[0] = QuoteLiquidationRouterIn({curveQuote: curveQuote1, wStableQuote: wStableQuote1});
        quoteIn[1] = QuoteLiquidationRouterIn({curveQuote: curveQuote2, wStableQuote: wStableQuote2});
        try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
            uint256[] memory results = abi.decode(removeFirst4Bytes(reason), (uint256[]));
            assertGt(results[0], 100 ether);
            assertGt(results[1], 100 ether);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}

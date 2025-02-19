// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

struct CurveQuote {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    address[5] _pools;
}

struct WStableQuote {
    address stablePool;
    int128 i;
    int128 j;
    uint256 amountIn;
}
struct QuoteLiquidationRouterIn {
    CurveQuote curveQuote;
    WStableQuote wStableQuote;
}

contract QuoteLiquidationRouter {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);

    error QuoteLiquidationRouterError(uint256[] quotes);

    constructor(QuoteLiquidationRouterIn[] memory routes) {
        uint256 routesLen = routes.length;
        uint256[] memory quotes = new uint256[](routesLen);

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i].curveQuote;
            WStableQuote memory wStableQuote = routes[i].wStableQuote;

            uint256 amountReceived = CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools);

            if (address(wStableQuote.stablePool) != address(0)) {
                amountReceived = ICurveStableSwapNG(wStableQuote.stablePool).get_dy(wStableQuote.i, wStableQuote.j, wStableQuote.amountIn);
            }

            quotes[i] = amountReceived;
            unchecked {
                ++i;
            }
        }
        revert QuoteLiquidationRouterError(quotes);
    }
}

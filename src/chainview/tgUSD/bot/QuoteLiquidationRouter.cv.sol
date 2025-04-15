// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import  {console} from "forge-std/console.sol";

struct CurveQuote {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    address[5] _pools;
}

contract QuoteLiquidationRouter {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    error QuoteLiquidationRouterError(uint256[] quotes);

    constructor(CurveQuote[] memory routes) {
        uint256 routesLen = routes.length;
        console.log(routesLen);
        uint256[] memory quotes = new uint256[](routesLen);
        // for (uint256 j; j < routesLen; ) {
        //      console.log(j, routes[j]._route[0]);
        //     unchecked {
        //         ++j;
        //     }
        // }
       

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i];

            quotes[i] = CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools);
            unchecked {
                ++i;
            }
        }
        revert QuoteLiquidationRouterError(quotes);
    }
}

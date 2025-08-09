// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {CurveQuote} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

contract QuotesCurveRouter {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    error QuotesCurveRouterError(uint256[] quotes);

    constructor(CurveQuote[] memory routes) {
        uint256 routesLen = routes.length;
        uint256[] memory quotes = new uint256[](routesLen);

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i];

            try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools) returns (uint256 quote) {
                quotes[i] = quote;
            } catch {
                quotes[i] = 0;
            }
            unchecked {
                ++i;
            }
        }
        revert QuotesCurveRouterError(quotes);
    }
}

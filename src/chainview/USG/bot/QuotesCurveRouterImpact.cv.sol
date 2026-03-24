// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {CurveQuote} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

struct QuoteWithImpact {
    uint256 quote;
    int256 priceImpact;
}

contract QuotesCurveRouterImpact {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    error QuotesCurveRouterImpactError(QuoteWithImpact[] outputs);

    constructor(CurveQuote[] memory routes) {
        uint256 routesLen = routes.length;
        QuoteWithImpact[] memory outputs = new QuoteWithImpact[](routesLen);

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i];
            uint256 quote;
            int256 priceImpact;

            try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools) returns (uint256 fullOutput) {
                quote = fullOutput;

                // Use a small nominal amount (0.1% of input) to approximate marginal price
                uint256 nominalAmount = curveQuote._amount >= 1000 ? curveQuote._amount / 1000 : 1;

                try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, nominalAmount, curveQuote._pools) returns (uint256 nominalOutput) {
                    if (nominalOutput > 0) {
                        // Scale nominal output to full size → expected output with zero slippage
                        uint256 expectedOutput = (nominalOutput * curveQuote._amount) / nominalAmount;

                        // Price impact = (expected - actual) / expected * 1e18
                        if (expectedOutput > 0) {
                            priceImpact = (int256(expectedOutput) - int256(quote)) * 1e18 / int256(expectedOutput);
                        }
                    }
                } catch {
                    // priceImpact remains 0
                }
            } catch {
                // quote and priceImpact remain 0
            }

            outputs[i] = QuoteWithImpact({quote: quote, priceImpact: priceImpact});

            unchecked { ++i; }
        }

        revert QuotesCurveRouterImpactError(outputs);
    }
}
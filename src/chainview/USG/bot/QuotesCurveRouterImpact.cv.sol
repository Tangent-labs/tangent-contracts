// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {CurveQuote} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct QuoteWithImpact {
    uint256 quote;
    int256 priceImpact;
}

contract QuotesCurveRouterImpact {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    uint256 private constant NOMINAL_DIVISOR = 1000;

    error QuotesCurveRouterImpactError(QuoteWithImpact[] outputs);

    constructor(CurveQuote[] memory routes) {
        uint256 routesLen = routes.length;
        QuoteWithImpact[] memory outputs = new QuoteWithImpact[](routesLen);

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i];
            uint256 quote;
            int256 priceImpact;

            try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools) returns (uint256 quoteResult) {
                quote = quoteResult;

                // Use a small reference trade, but avoid sub-token amounts that are too noisy on LP routes.
                uint256 tokenUnit;
                try IERC20Metadata(curveQuote._route[0]).decimals() returns (uint8 d) {
                    tokenUnit = 10 ** d;
                } catch {
                    tokenUnit = 1;
                }
                uint256 scaledAmount = curveQuote._amount / NOMINAL_DIVISOR;
                uint256 marginalAmount = scaledAmount < tokenUnit ? tokenUnit : scaledAmount;
                if (marginalAmount > curveQuote._amount) marginalAmount = curveQuote._amount;
                if (marginalAmount == 0) marginalAmount = 1;

                // Calculate price impact by comparing with marginal price
                try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, marginalAmount, curveQuote._pools) returns (uint256 marginalQuote) {
                    if (marginalQuote > 0 && curveQuote._amount > 0) {
                        // Expected output at marginal price (no slippage)
                        uint256 expectedOutput = (curveQuote._amount * marginalQuote) / marginalAmount;
                        if (expectedOutput > quote) {
                            priceImpact = int256(((expectedOutput - quote) * 1e18) / expectedOutput);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {CurveQuote} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {console} from "hardhat/console.sol";


struct QuoteWithImpact {
    uint256 quote;
    int256 priceImpact;
}

contract QuotesCurveRouterImpact {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    uint256 private constant MARGINAL_AMOUNT = 1 ether;

    error QuotesCurveRouterImpactError(QuoteWithImpact[] outputs);

    constructor(CurveQuote[] memory routes) {
        uint256 routesLen = routes.length;
        QuoteWithImpact[] memory outputs = new QuoteWithImpact[](routesLen);

        for (uint256 i; i < routesLen; ) {
            CurveQuote memory curveQuote = routes[i];
            uint256 quote = 0;
            int256 priceImpact = 0;

            try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, curveQuote._amount, curveQuote._pools) returns (uint256 quoteResult) {
                quote = quoteResult;
                
                // Calculate price impact by comparing with marginal price
                try CURVE_ROUTER.get_dy(curveQuote._route, curveQuote._swap_params, MARGINAL_AMOUNT, curveQuote._pools) returns (uint256 marginalQuote) {

                  
                        console.log( "marginalQuote: ", marginalQuote);
                        console.log( "quote: ", quote);
                      //  console.logInt(  priceImpact);
                    if (marginalQuote > 0 && curveQuote._amount > 0) {
                        // Expected output at marginal price (no slippage)
                        uint256 expectedOutput = (curveQuote._amount * marginalQuote) / MARGINAL_AMOUNT;
                        if (expectedOutput > 0) {
                            // Price impact as percentage: (expected - actual) / expected * 1e18
                            priceImpact = (int256(expectedOutput) - int256(quote)) * 1e18 / int256(expectedOutput);
                            console.logInt(  priceImpact);
                        }
                     
                    } 
                } catch {
                   // no price impact
                }
            } catch {
              // no quote
            }

            outputs[i] = QuoteWithImpact({
                quote: quote,
                priceImpact: priceImpact
            });

            unchecked {
                ++i;
            }
        }
        revert QuotesCurveRouterImpactError(outputs);
    }
}

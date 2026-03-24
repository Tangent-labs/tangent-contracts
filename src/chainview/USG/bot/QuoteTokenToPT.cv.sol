// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

import {CurveQuote} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";

struct PendleSYToPTQuote {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingIn;
    uint256 tokenInAmount;
}

struct QuoteTokenToPTParams {
    CurveQuote curveRouterData;
    PendleSYToPTQuote syToPTData;
}

struct QuoteTokenToPTOut {
    uint256 quote;
    int256 priceImpact;
}

contract QuoteTokenToPT {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    error QuoteTokenToPTError(QuoteTokenToPTOut[] quotes);

    constructor(QuoteTokenToPTParams[] memory params) {
        revert QuoteTokenToPTError(_getQuotesPTOut(params));
    }

    function _getQuotesPTOut(QuoteTokenToPTParams[] memory routesPTOut) internal view returns (QuoteTokenToPTOut[] memory) {
        uint256 len = routesPTOut.length;
        QuoteTokenToPTOut[] memory quotes = new QuoteTokenToPTOut[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTOut(routesPTOut[index]);
        }
        return quotes;
    }

    function _getQuotePTOut(QuoteTokenToPTParams memory param) internal view returns (QuoteTokenToPTOut memory out) {
        PendleSYToPTQuote memory pendle = param.syToPTData;
        CurveQuote memory curve = param.curveRouterData;

        uint256 ptDecimals = pendle.pt.decimals();

        // 1. Get PT → SY rate from Pendle oracle
        uint256 ptToSYRate;
        try oracle.getPtToSyRate(address(pendle.market), 100) returns (uint256 rate) {
            ptToSYRate = rate;
        } catch {
            return out;
        }

        // 2. Quote full token → underlying on Curve
        uint256 underlyingOut;
        try CURVE_ROUTER.get_dy(curve._route, curve._swap_params, pendle.tokenInAmount, curve._pools) returns (uint256 under) {
            underlyingOut = under;
        } catch {
            return out;
        }

        // 3. Deposit underlying → SY, then derive PT amount out
        try pendle.sy.previewDeposit(pendle.underlyingIn, underlyingOut) returns (uint256 syAmount) {
            out.quote = (syAmount * 10 ** ptDecimals) / ptToSYRate;
        } catch {
            return out;
        }

        // 4. Calculate price impact using a small nominal trade
        uint256 nominalAmount = pendle.tokenInAmount >= 1000 ? pendle.tokenInAmount / 1000 : 1;

        // Get nominal underlying out on Curve
        uint256 nominalUnderlyingOut;
        try CURVE_ROUTER.get_dy(curve._route, curve._swap_params, nominalAmount, curve._pools) returns (uint256 under) {
            nominalUnderlyingOut = under;
        } catch {
            return out;
        }

        // Get nominal SY → PT out
        try pendle.sy.previewDeposit(pendle.underlyingIn, nominalUnderlyingOut) returns (uint256 nominalSYAmount) {
            uint256 nominalPTOut = (nominalSYAmount * 10 ** ptDecimals) / ptToSYRate;
            if (nominalPTOut == 0) return out;

            // Scale nominal output to full size → "expected" output with zero slippage
            uint256 expectedOutput = (nominalPTOut * pendle.tokenInAmount) / nominalAmount;

            // Price impact = (expected - actual) / expected * 1e18
            // Positive = you lose to slippage, Negative = you gain (rare)
            if (expectedOutput > 0) {
                out.priceImpact = ((int256(expectedOutput) - int256(out.quote)) * int256(1e18)) / int256(expectedOutput);
            }
        } catch {
            // priceImpact remains 0 if nominal quote fails
        }

        return out;
    }
}
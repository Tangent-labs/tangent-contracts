// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";
import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";

import {CurveRouteParamsOnly} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";

struct QuotePTToTokenParams {
    PendlePTToSYQuote ptToSYData;
    CurveRouteParamsOnly curveRouterData;
}

struct PendlePTToSYQuote {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingOut;
    uint256 ptAmount;
}

struct QuotePtToTokenOut {
    uint256 quote;
    int256 priceImpact;
}

contract QuotePTToToken {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    error QuotePTToTokenError(QuotePtToTokenOut[] quotes);

    constructor(QuotePTToTokenParams[] memory params) {
        revert QuotePTToTokenError(_getQuotesPTIn(params));
    }

    function _getQuotesPTIn(QuotePTToTokenParams[] memory params) internal view returns (QuotePtToTokenOut[] memory) {
        uint256 len = params.length;
        QuotePtToTokenOut[] memory quotes = new QuotePtToTokenOut[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTIn(params[index]);
        }
        return quotes;
    }

    function _getQuotePTIn(QuotePTToTokenParams memory param) internal view returns (QuotePtToTokenOut memory out) {
        PendlePTToSYQuote memory ptToSY = param.ptToSYData;
        CurveRouteParamsOnly memory curve = param.curveRouterData;

        uint256 ptDecimals = ptToSY.pt.decimals();

        // 1. Get PT → SY rate from Pendle oracle
        uint256 ptToSYRate;
        try oracle.getPtToSyRate(address(ptToSY.market), 100) returns (uint256 rate) {
            ptToSYRate = rate;
        } catch {
            return out;
        }

        // 2. Calculate full underlying amount out from PT (via SY previewRedeem)
        uint256 underlyingQuoteOut;
        try ptToSY.sy.previewRedeem(
            ptToSY.underlyingOut,
            (ptToSYRate * ptToSY.ptAmount) / 10 ** ptDecimals
        ) returns (uint256 underOut) {
            underlyingQuoteOut = underOut;
        } catch {
            return out;
        }

        // 3. Quote the full underlying → final token swap on Curve
        try CURVE_ROUTER.get_dy(
            curve._route,
            curve._swap_params,
            underlyingQuoteOut,
            curve._pools
        ) returns (uint256 fullOutput) {
            out.quote = fullOutput;
        } catch {
            return out;
        }

        // 4. Calculate price impact using a small nominal trade on Curve
        uint256 nominalAmount = ptDecimals >= 3 ? 10 ** (ptDecimals - 3) : 1; // 0.001 PT, guarded against underflow

        // Get nominal underlying amount
        uint256 nominalUnderlyingOut = 0;
        try ptToSY.sy.previewRedeem(
            ptToSY.underlyingOut,
            (ptToSYRate * nominalAmount) / 10 ** ptDecimals
        ) returns (uint256 underOut) {
            nominalUnderlyingOut = underOut;
        } catch {
            return out;
        }

        // Get nominal output on Curve (tiny trade = close to marginal price)
        try CURVE_ROUTER.get_dy(
            curve._route,
            curve._swap_params,
            nominalUnderlyingOut,
            curve._pools
        ) returns (uint256 nominalOutput) {
            if (nominalOutput == 0) return out;

            // Scale nominal output to full size → this is the "expected" output with zero slippage
            uint256 expectedOutput = (nominalOutput * ptToSY.ptAmount) / nominalAmount;

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
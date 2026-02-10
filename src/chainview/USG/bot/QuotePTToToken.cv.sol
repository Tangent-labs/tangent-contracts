// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";

import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

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
        CurveRouteParamsOnly memory paramCurve = param.curveRouterData;
        uint256 ptDecimals = ptToSY.pt.decimals();

        // Find the swap rate of PT to SY
        uint256 ptToSYRate;
        try oracle.getPtToSyRate(address(ptToSY.market), 100) returns (uint256 rate) {
            ptToSYRate = rate;
        } catch {
            return out;
        }
        // Find the swap rate of SY to underlying for the full amount
        uint256 underlyingQuoteOut;
        try ptToSY.sy.previewRedeem(ptToSY.underlyingOut, (ptToSYRate * ptToSY.ptAmount) / 10 ** ptDecimals) returns (uint256 underOut) {
            underlyingQuoteOut = underOut;
        } catch {
            return out;
        }
        // Find the swap rate of SY to underlying for the full amount
        uint256 nominalAmount = 10 ** (ptDecimals - 3);
        uint256 nominalUnderlyingQuoteOut;
        try ptToSY.sy.previewRedeem(ptToSY.underlyingOut, (ptToSYRate * nominalAmount) / 10 ** ptDecimals) returns (uint256 underOut) {
            nominalUnderlyingQuoteOut = underOut;
        } catch {}
        // Quote the swap of underlying to Token
        try CURVE_ROUTER.get_dy(paramCurve._route, paramCurve._swap_params, underlyingQuoteOut, paramCurve._pools) returns (uint256 q) {
            out.quote = q;
        } catch {
            return out;
        }
        try CURVE_ROUTER.get_dy(paramCurve._route, paramCurve._swap_params, nominalUnderlyingQuoteOut, paramCurve._pools) returns (uint256 q) {
            uint256 expectedOutput = (out.quote * q) / nominalAmount;
            out.priceImpact = ((int256(expectedOutput) - int256(underlyingQuoteOut)) * int256(1e18)) / int256(expectedOutput);
        } catch {
            return out;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";

import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

import {CurveRouterSwapNoAmount} from "../../../interfaces/internals/USG/IPendlePTRouter.sol";

struct PendlePTToSYQuote {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingOut;
    uint256 ptAmount;
}

struct PendleSYToPTQuote {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingIn;
    uint256 tokenInAmount;
}

struct PendlePTInQuoteParams {
    CurveRouterSwapNoAmount curveRouterData;
    PendlePTToSYQuote ptToSYData;
}

struct PendlePTOutQuoteParams {
    CurveRouterSwapNoAmount curveRouterData;
    PendleSYToPTQuote syToPTData;
}

contract QuotesPendlePT {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    error QuotesPendlePTError(uint256[] quotesPTIn, uint256[] quotesPTOut);

    constructor(PendlePTInQuoteParams[] memory routesPTInParams, PendlePTOutQuoteParams[] memory routesPTOutParams) {
        revert QuotesPendlePTError(_getQuotesPTIn(routesPTInParams), _getQuotesPTOut(routesPTOutParams));
    }

    function _getQuotesPTIn(PendlePTInQuoteParams[] memory routesPTIn) internal view returns (uint256[] memory) {
        uint256 len = routesPTIn.length;
        uint256[] memory quotes = new uint256[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTIn(routesPTIn[index]);
        }
        return quotes;
    }

    function _getQuotePTIn(PendlePTInQuoteParams memory routesPTIn) internal view returns (uint256) {
        PendlePTToSYQuote memory param = routesPTIn.ptToSYData;
        CurveRouterSwapNoAmount memory paramCurve = routesPTIn.curveRouterData;

        uint256 ptToSYRate;
        try oracle.getPtToSyRate(address(param.market), 100) returns (uint256 rate) {
            ptToSYRate = rate;
        } catch {
            return 0;
        }
        uint256 underlyingOut;
        try param.sy.previewRedeem(param.underlyingOut, (ptToSYRate * param.ptAmount) / 10 ** (param.pt.decimals())) returns (uint256 underOut) {
            underlyingOut = underOut;
        } catch {
            return 0;
        }

        try CURVE_ROUTER.get_dy(paramCurve._route, paramCurve._swap_params, underlyingOut, paramCurve._pools) returns (uint256 q) {
            return q;
        } catch {
            return 0;
        }
    }

    function _getQuotesPTOut(PendlePTOutQuoteParams[] memory routesPTOut) internal view returns (uint256[] memory) {
        uint256 len = routesPTOut.length;
        uint256[] memory quotes = new uint256[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTOut(routesPTOut[index]);
        }
        return quotes;
    }

    function _getQuotePTOut(PendlePTOutQuoteParams memory routesPTOut) internal view returns (uint256) {
        PendleSYToPTQuote memory param = routesPTOut.syToPTData;
        CurveRouterSwapNoAmount memory paramCurve = routesPTOut.curveRouterData;

        uint256 underlyingOut;
        try CURVE_ROUTER.get_dy(paramCurve._route, paramCurve._swap_params, param.tokenInAmount, paramCurve._pools) returns (uint256 under) {
            underlyingOut = under;
        } catch {
            return 0;
        }

        uint256 syAmount;
        try param.sy.previewDeposit(param.underlyingIn, underlyingOut) returns (uint256 syAm) {
            syAmount = syAm;
        } catch {
            return 0;
        }

        try oracle.getPtToSyRate(address(param.market), 100) returns (uint256 rate) {
            return (syAmount * 10 ** (param.pt.decimals())) / rate;
        } catch {
            return 0;
        }
    }
}

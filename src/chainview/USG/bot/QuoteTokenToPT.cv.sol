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

contract QuoteTokenToPT {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    error QuoteTokenToPTError(uint256[] quotes);

    constructor(QuoteTokenToPTParams[] memory params) {
        revert QuoteTokenToPTError(_getQuotesPTOut(params));
    }

    function _getQuotesPTOut(QuoteTokenToPTParams[] memory routesPTOut) internal view returns (uint256[] memory) {
        uint256 len = routesPTOut.length;
        uint256[] memory quotes = new uint256[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTOut(routesPTOut[index]);
        }
        return quotes;
    }

    function _getQuotePTOut(QuoteTokenToPTParams memory routesPTOut) internal view returns (uint256) {
        PendleSYToPTQuote memory paramPendle = routesPTOut.syToPTData;
        CurveQuote memory paramCurve = routesPTOut.curveRouterData;

        uint256 underlyingOut;
        try CURVE_ROUTER.get_dy(paramCurve._route, paramCurve._swap_params, paramPendle.tokenInAmount, paramCurve._pools) returns (uint256 under) {
            underlyingOut = under;
        } catch {
            return 0;
        }

        uint256 syAmount;
        try paramPendle.sy.previewDeposit(paramPendle.underlyingIn, underlyingOut) returns (uint256 syAm) {
            syAmount = syAm;
        } catch {
            return 0;
        }

        try oracle.getPtToSyRate(address(paramPendle.market), 100) returns (uint256 rate) {
            return (syAmount * 10 ** (paramPendle.pt.decimals())) / rate;
        } catch {
            return 0;
        }
    }
}

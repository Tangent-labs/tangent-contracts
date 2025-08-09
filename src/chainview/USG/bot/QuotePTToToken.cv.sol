// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICurveRouter} from "../../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleMarketV3} from "../../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../../interfaces/externals/Pendle/IPendleSYToken.sol";

import {IPendlePYLpOracle} from "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";

import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

import {CurveRouteParamsOny} from "../../../interfaces/internals/USG/ICurveLPLiquidator.sol";

struct QuotePTToTokenParams {
    PendlePTToSYQuote ptToSYData;
    CurveRouteParamsOny curveRouterData;
}

struct PendlePTToSYQuote {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingOut;
    uint256 ptAmount;
}

contract QuotePTToToken {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    error QuotePTToTokenError(uint256[] quotes);

    constructor(QuotePTToTokenParams[] memory params) {
        revert QuotePTToTokenError(_getQuotesPTIn(params));
    }

    function _getQuotesPTIn(QuotePTToTokenParams[] memory params) internal view returns (uint256[] memory) {
        uint256 len = params.length;
        uint256[] memory quotes = new uint256[](len);

        for (uint256 index = 0; index < len; index++) {
            quotes[index] = _getQuotePTIn(params[index]);
        }
        return quotes;
    }

    function _getQuotePTIn(QuotePTToTokenParams memory param) internal view returns (uint256) {
        PendlePTToSYQuote memory ptToSY = param.ptToSYData;
        CurveRouteParamsOny memory paramCurve = param.curveRouterData;

        uint256 ptToSYRate;
        try oracle.getPtToSyRate(address(ptToSY.market), 100) returns (uint256 rate) {
            ptToSYRate = rate;
        } catch {
            return 0;
        }
        uint256 underlyingOut;
        try ptToSY.sy.previewRedeem(ptToSY.underlyingOut, (ptToSYRate * ptToSY.ptAmount) / 10 ** (ptToSY.pt.decimals())) returns (uint256 underOut) {
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
}

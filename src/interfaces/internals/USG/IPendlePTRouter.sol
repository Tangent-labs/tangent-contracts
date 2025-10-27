// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPendleSYToken} from "../../externals/Pendle/IPendleSYToken.sol";
import {IPendleYTToken} from "../../externals/Pendle/IPendleYTToken.sol";
import {IPendlePTToken} from "../../externals/Pendle/IPendlePTToken.sol";
import {IPendleMarketV3} from "../../externals/Pendle/IPendleMarketV3.sol";

import {CurveRouterSwap, CurveRouterSwapNoAmount, CurveRouterSwapNoReceiver} from "./ICurveLPLiquidator.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct PendlePTToSY {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    IPendleYTToken yt;
    address underlyingOut;
    uint256 ptAmount;
}

struct PendleSYToPT {
    IPendleMarketV3 market;
    IPendlePTToken pt;
    IPendleSYToken sy;
    address underlyingIn;
    address receiver;
    uint256 minPTOut;
}

interface IPendlePTRouter {
    function swapPTForPT(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData, PendleSYToPT calldata SYToPT) external payable returns (uint256);
    function swapPTForToken(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256);
    function swapTokenForPT(CurveRouterSwapNoReceiver calldata crvRouterData, PendleSYToPT calldata SYToPT) external payable returns (uint256);
}

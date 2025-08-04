// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPendleSYToken} from "../../externals/Pendle/IPendleSYToken.sol";
import {IPendleYTToken} from "../../externals/Pendle/IPendleYTToken.sol";
import {IPendlePTToken} from "../../externals/Pendle/IPendlePTToken.sol";
import {IPendleMarketV3} from "../../externals/Pendle/IPendleMarketV3.sol";
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
    uint256 tokenInAmount;
    uint256 minPTOut;
}

struct CurveRouterSwapNoAmount {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _min_dy;
    address[5] _pools;
    address _receiver;
}

interface IPendlePTRouter {
    function swapPTForToken(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256);
    function swapTokenForPT(PendleSYToPT calldata SYToPT, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256);
}

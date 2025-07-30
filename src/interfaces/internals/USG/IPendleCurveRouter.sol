// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPendleSYToken} from "../../externals/Pendle/IPendleSYToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct PendlePTToSY {
    address market;
    IERC20 pt;
    IPendleSYToken sy;
    address tokenOut;
    uint256 ptAmount;
}

struct PendleSYToPT {
    address market;
    IERC20 pt;
    IPendleSYToken sy;
    address tokenIn;
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

interface IPendleCurveRouter {
    function swapPTForToken(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256);
    function swapTokenForPT(PendleSYToPT calldata SYToPT, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256);
}

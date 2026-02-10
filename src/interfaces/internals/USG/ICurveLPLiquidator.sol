// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

struct CurveRouterSwap {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    uint256 _min_dy;
    address[5] _pools;
    address _receiver;
}

struct CurveRouterSwapNoReceiver {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    address[5] _pools;
}

struct CurveRouterSwapNoAmount {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _min_dy;
    address[5] _pools;
    address _receiver;
}

struct CurveQuote {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    address[5] _pools;
}

struct CurveRouteParamsOnly {
    address[11] _route;
    uint256[5][5] _swap_params;
    address[5] _pools;
}

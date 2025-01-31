// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

struct MintAndSwapWStable {
    address stable;
    address wStable;
    address stablePool;
    address receiver;
    int128 i;
    int128 j;
    uint256 amountIn;
    uint256 amountMinOut;
}

struct CurveRouterSwap {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    uint256 _min_dy;
    address[5] _pools;
    address _receiver;
}

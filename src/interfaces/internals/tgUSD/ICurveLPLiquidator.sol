// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

struct RemoveLiquidityCollateral {
    address lpToLiquidate;
    uint256 amountToLiquidate;
    uint256 lpType;
    uint256[2] minAmounts;
}

struct CurveRouterSwap {
    address[11] _route;
    uint256[5][5] _swap_params;
    uint256 _amount;
    uint256 _min_dy;
    address[5] _pools;
    address _receiver;
}

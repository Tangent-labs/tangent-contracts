// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RemoveLiquidityCollateral, CurveRouterSwap} from "../../src/interfaces/internals/tgUSD/ICurveLPLiquidator.sol";

contract Encoder {
    function encodeLiquidateCallForCurveLP(
        RemoveLiquidityCollateral calldata removeLiquidity,
        CurveRouterSwap calldata curveRouterSwap,
        uint256 debtToCover
    ) public pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("liquidateLP((address,uint256,uint256,uint256[2]),(address[11],uint256[5][5],uint256,uint256,address[5],address),uint256)")),
                removeLiquidity,
                curveRouterSwap,
                debtToCover
            );
    }

    function createCurveRouterStruct(
        address[] calldata route,
        uint256[][] calldata swapParams,
        uint256 amount,
        uint256 minDy,
        address receiver
    ) public pure returns (CurveRouterSwap memory) {
        uint256 ZERO = 0;
        address[11] memory _route = [address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];

        for (uint256 i; i < route.length; i++) {
            _route[i] = route[i];
        }

        uint256[5][5] memory _swapParams = [
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        for (uint256 i; i < swapParams.length; i++) {
            for (uint256 j; j < swapParams[i].length; j++) {
                _swapParams[i][j] = swapParams[i][j];
            }
        }
        address[5] memory pools;
        return CurveRouterSwap({_route: _route, _swap_params: _swapParams, _amount: amount, _min_dy: minDy, _pools: pools, _receiver: receiver});
    }
}

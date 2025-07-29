// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveRouterSwap} from "../../src/interfaces/internals/USG/ICurveLPLiquidator.sol";
import {ZapStruct} from "../../src/interfaces/internals/ICommonStruct.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

contract Encoder {
    function encodeSwapToMockRouter(address router, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, address receiver, uint256 amountOut) public pure returns (ZapStruct memory) {
        return
            ZapStruct({
                router: router,
                routerCall: abi.encodeWithSelector(bytes4(keccak256("swap(address,uint256,address,address,uint256)")), tokenIn, amountIn, tokenOut, receiver, amountOut)
            });
    }

    function encodeLiquidateCallForCurveLP(CurveRouterSwap calldata curveRouterSwap) public pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("exchange(address[11],uint256[5][5],uint256,uint256,address[5],address)")), curveRouterSwap);
    }

    function encodeLiquidateCallForPendlePT(address market, uint256 amountIn) public pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("swapPtForUSG(uint256,uint256)")), market, amountIn);
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

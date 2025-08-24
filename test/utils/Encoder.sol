// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveRouterSwap, CurveQuote} from "../../src/interfaces/internals/USG/ICurveLPLiquidator.sol";
import {IPendlePTRouter, CurveRouterSwapNoAmount, PendlePTToSY, PendleSYToPT} from "../../src/interfaces/internals/USG/IPendlePTRouter.sol";

import {ICurveRouter} from "../../src/interfaces/externals/Curve/ICurveRouter.sol";
import {IPendleRouterV4, TokenOutput, LimitOrderData} from "../../src/interfaces/externals/Pendle/IPendleRouterV4.sol";

import {ZapStruct} from "../../src/interfaces/internals/ICommonStruct.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Encoder {
    function encodeSwapToMockRouter(address router, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, address receiver, uint256 amountOut) public pure returns (ZapStruct memory) {
        return
            ZapStruct({
                router: router,
                routerCall: abi.encodeWithSelector(bytes4(keccak256("swap(address,uint256,address,address,uint256)")), tokenIn, amountIn, tokenOut, receiver, amountOut)
            });
    }

    function encodeLiquidateCallForCurveLP(CurveRouterSwap calldata curveRouterSwap) public pure returns (bytes memory) {
        return abi.encodeWithSelector(ICurveRouter.exchange.selector, curveRouterSwap);
    }

    function encodeSwapPTForToken(PendlePTToSY calldata pendlePTToSY, CurveRouterSwapNoAmount calldata curveSwapParams) public pure returns (bytes memory) {
        return abi.encodeWithSelector(IPendlePTRouter.swapPTForToken.selector, pendlePTToSY, curveSwapParams);
    }

    function encodeSwapTokenForPT(CurveRouterSwap calldata curveSwapParams, PendleSYToPT calldata pendleSYToPT) public pure returns (bytes memory) {
        return abi.encodeWithSelector(IPendlePTRouter.swapTokenForPT.selector, curveSwapParams, pendleSYToPT);
    }

    function encodeSwapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) public pure returns (bytes memory) {
        return abi.encodeWithSelector(IPendleRouterV4.swapExactPtForToken.selector, receiver, market, exactPtIn, output, limit);
    }

    function encodeSwapPTForPT(
        PendlePTToSY calldata pendlePTToSY,
        CurveRouterSwapNoAmount calldata curveSwapParams,
        PendleSYToPT calldata pendleSYToPT
    ) public pure returns (bytes memory) {
        return abi.encodeWithSelector(IPendlePTRouter.swapPTForPT.selector, pendlePTToSY, curveSwapParams, pendleSYToPT);
    }

    function createCurveQuoteStruct(address[] calldata route, uint256[][] calldata swapParams, uint256 amount) public pure returns (CurveQuote memory) {
        (address[11] memory _route, uint256[5][5] memory _swapParams) = _prepareCurveRouterArrays(route, swapParams);
        address[5] memory pools;
        return CurveQuote({_route: _route, _swap_params: _swapParams, _amount: amount, _pools: pools});
    }

    function createCurveRouterStruct(
        address[] calldata route,
        uint256[][] calldata swapParams,
        uint256 amount,
        uint256 minDy,
        address receiver
    ) public pure returns (CurveRouterSwap memory) {
        (address[11] memory _route, uint256[5][5] memory _swapParams) = _prepareCurveRouterArrays(route, swapParams);
        address[5] memory pools;
        return CurveRouterSwap({_route: _route, _swap_params: _swapParams, _amount: amount, _min_dy: minDy, _pools: pools, _receiver: receiver});
    }

    function createCurveRouterNoAmountStruct(
        address[] calldata route,
        uint256[][] calldata swapParams,
        uint256 minDy,
        address receiver
    ) public pure returns (CurveRouterSwapNoAmount memory) {
        (address[11] memory _route, uint256[5][5] memory _swapParams) = _prepareCurveRouterArrays(route, swapParams);
        address[5] memory pools;

        return CurveRouterSwapNoAmount({_route: _route, _swap_params: _swapParams, _min_dy: minDy, _pools: pools, _receiver: receiver});
    }

    function _prepareCurveRouterArrays(address[] calldata route, uint256[][] calldata swapParams) internal pure returns (address[11] memory, uint256[5][5] memory) {
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

        return (_route, _swapParams);
    }
}

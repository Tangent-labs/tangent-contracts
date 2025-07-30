// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IPendleRouterV4, TokenOutput, LimitOrderData, ApproxParams} from "../../interfaces/externals/Pendle/IPendleRouterV4.sol";

import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";

import {CurveRouterSwapNoAmount, PendlePTToSY, PendleSYToPT} from "../../interfaces/internals/USG/IPendleCurveRouter.sol";
import {CurveRouterSwap} from "../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleCurveRouter {
    uint256 constant MAX_UINT = type(uint256).max;
    IPendleRouterV4 public constant pendleRouter = IPendleRouterV4(0x888888888889758F76e7103c6CbF23ABbF58F946);
    ICurveRouter public constant curveRouter = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    function swapPTForToken(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256) {
        PTToSY.pt.transferFrom(msg.sender, address(this), PTToSY.ptAmount);

        _approveIfNotAllowed(PTToSY.pt, address(pendleRouter));

        (uint256 syOut, ) = pendleRouter.swapExactPtForSy(address(this), PTToSY.market, PTToSY.ptAmount, 0, createEmptyLimitOrderData());

        uint256 amountUnderlyingOut = PTToSY.sy.redeem(address(this), syOut, PTToSY.tokenOut, 0, false);

        _approveIfNotAllowed(IERC20(PTToSY.tokenOut), address(curveRouter));
        return _curveExchange(crvRouterData, amountUnderlyingOut);
    }

    function swapTokenForPT(PendleSYToPT calldata SYToPT, CurveRouterSwapNoAmount calldata crvRouterData) external returns (uint256) {
        IERC20 tokenIn = IERC20(crvRouterData._route[0]);
        tokenIn.transferFrom(msg.sender, address(this), SYToPT.tokenInAmount);

        _approveIfNotAllowed(tokenIn, address(curveRouter));

        // Swap USG for PT underlying
        uint256 underlyingAmount = _curveExchange(crvRouterData, SYToPT.tokenInAmount);

        _approveIfNotAllowed(IERC20(SYToPT.tokenIn), address(SYToPT.sy));

        uint256 syAmount = SYToPT.sy.deposit(address(this), SYToPT.tokenIn, underlyingAmount, 0);

        _approveIfNotAllowed(SYToPT.sy, address(pendleRouter));

        (uint256 ptOut, ) = pendleRouter.swapExactSyForPt(SYToPT.receiver, SYToPT.market, syAmount, SYToPT.minPTOut, createDefaultApproxParams(), createEmptyLimitOrderData());

        return ptOut;
    }

    function _approveIfNotAllowed(IERC20 token, address spender) internal {
        if (token.allowance(address(this), address(spender)) != MAX_UINT) {
            token.approve(address(spender), MAX_UINT);
        }
    }

    function _curveExchange(CurveRouterSwapNoAmount calldata crvRouterData, uint256 amountIn) internal returns (uint256) {
        return curveRouter.exchange(crvRouterData._route, crvRouterData._swap_params, amountIn, crvRouterData._min_dy, crvRouterData._pools, crvRouterData._receiver);
    }

    function createEmptyLimitOrderData() internal pure returns (LimitOrderData memory) {}

    function createDefaultApproxParams() internal pure returns (ApproxParams memory) {
        return ApproxParams({guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1e14});
    }
}

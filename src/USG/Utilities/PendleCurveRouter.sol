// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IPendleRouterV4, TokenOutput, LimitOrderData, ApproxParams} from "../../interfaces/externals/Pendle/IPendleRouterV4.sol";

import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";

import {CurveRouterExchange, PendlePTToSY} from "../../interfaces/internals/USG/IPendleCurveRouter.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleCurveRouter {
    uint256 constant MAX_UINT = type(uint256).max;
    IPendleRouterV4 public constant pendleRouter = IPendleRouterV4(0x888888888889758F76e7103c6CbF23ABbF58F946);
    ICurveRouter public constant curveRouter = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    function swapPtForToken(PendlePTToSY calldata PTToSY, CurveRouterExchange calldata crvRouterData) external returns (uint256) {
        _approveIfNotAllowed(PTToSY.pt, address(pendleRouter));

        (uint256 syOut, ) = pendleRouter.swapExactPtForSy(address(this), PTToSY.market, PTToSY.ptAmount, PTToSY.minSYOut, createEmptyLimitOrderData());

        uint256 amountUnderlyingOut = PTToSY.sy.redeem(address(this), syOut, PTToSY.tokenOut, PTToSY.minTokenOutOut, false);

        if (crvRouterData._route[0] != address(0)) {
            return _curveExchange(crvRouterData, amountUnderlyingOut);
        } else {
            return amountUnderlyingOut;
        }
    }

    // function swapTokenForPT(PendleSYToPT calldata SYToPT, CurveRouterExchange calldata crvRouterData) external returns (uint256) {
    //     _approveIfNotAllowed(IERC20(crvRouterData._route[0]), address(curveRouter));

    //     // Swap USG for PT underlying
    //     uint256 underlyingAmount = _curveExchange(crvRouterData);

    //     uint256 syAmount = PendleSYToPT.sy.deposit(address(this), PendleSYToPT.token, underlyingAmount, PendleSYToPT.minTokenOutOut);

    //     PendleSYToPT.pt.approve(address(pendleRouter), PendleSYToPT.amount);

    //     (uint256 syOut, ) = pendleRouter.swapExactSyForPt(
    //         address(this),
    //         PendleSYToPT.market,
    //         PendleSYToPT.amount,
    //         PendleSYToPT.minSYOut,
    //         createDefaultApproxParams(),
    //         createEmptyLimitOrderData()
    //     );
    // }

    function _approveIfNotAllowed(IERC20 token, address spender) internal {
        if (token.allowance(address(this), address(spender)) != MAX_UINT) {
            token.approve(address(spender), MAX_UINT);
        }
    }

    function _curveExchange(CurveRouterExchange calldata crvRouterData, uint256 amountIn) internal returns (uint256) {
        return curveRouter.exchange(crvRouterData._route, crvRouterData._swap_params, amountIn, crvRouterData._min_dy, crvRouterData._pools, crvRouterData._receiver);
    }

    function createEmptyLimitOrderData() internal pure returns (LimitOrderData memory) {}

    function createDefaultApproxParams() internal pure returns (ApproxParams memory) {
        return ApproxParams({guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1e14});
    }
}

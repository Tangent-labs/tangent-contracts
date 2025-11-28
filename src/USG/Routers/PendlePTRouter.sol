// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IPendleRouterV4, TokenOutput, LimitOrderData, ApproxParams} from "../../interfaces/externals/Pendle/IPendleRouterV4.sol";

import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";

import {CurveRouterSwapNoAmount, CurveRouterSwapNoReceiver, PendlePTToSY, PendleSYToPT} from "../../interfaces/internals/USG/IPendlePTRouter.sol";

import {CurveRouterSwap} from "../../interfaces/internals/USG/ICurveLPLiquidator.sol";
import {IPendlePTRouter} from "../../interfaces/internals/USG/IPendlePTRouter.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  PendlePTRouter
/// @notice Swaps ERC20 for PT and vice versa through Pendle and Curve Router.
contract PendlePTRouter is IPendlePTRouter {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT = type(uint256).max;
    IPendleRouterV4 public constant pendleRouter = IPendleRouterV4(0x888888888889758F76e7103c6CbF23ABbF58F946);
    ICurveRouter public constant curveRouter = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @notice Swaps a PT from Pendle to an other PT from Pendle using the router of Pendle and Curve.
     * @dev    Used for doing migrations ( PT-A => PT-B )
     * @param  PTToSY  Struct containing data to perform the swaps from PT to Underlying :
     *                          - market : Address of the Pendle LP market
     *                          - pt : Address of the Pendle PT
     *                          - sy : Address of the Pendle SY
     *                          - yt : Address of the Pendle YT
     *                          - underlyingOut : Address of the underlying out on SY => Underlying
     *                          - ptAmount : Amount of PT to sell
     * @param  crvRouterData  Struct containing data to perform a swap through the Curve Router
     */
    function swapPTForPT(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData, PendleSYToPT calldata SYToPT) public payable returns (uint256) {
        uint256 underlyingOut = swapPTForToken(PTToSY, crvRouterData);

        return _swapUnderlyingToPT(underlyingOut, SYToPT);
    }

    /**
     * @notice Swaps a PT from Pendle to an other ERC20 using the router of Pendle and Curve.
     * @dev    Used for doing liquidations ( PT => USG )
     * @param  PTToSY  Struct containing data to perform the swaps from PT to Underlying :
     *                          - market : Address of the Pendle LP market
     *                          - pt : Address of the Pendle PT
     *                          - sy : Address of the Pendle SY
     *                          - yt : Address of the Pendle YT
     *                          - underlyingOut : Address of the underlying out on SY => Underlying
     *                          - ptAmount : Amount of PT to sell
     * @param  crvRouterData  Struct containing data to perform a swap through the Curve Router
     */
    function swapPTForToken(PendlePTToSY calldata PTToSY, CurveRouterSwapNoAmount calldata crvRouterData) public returns (uint256) {
        uint256 syOut;

        // When a market is expired
        if (PTToSY.market.isExpired()) {
            // Transfers directly the PT to the YT prior to burn
            _transferFrom(PTToSY.pt, msg.sender, address(PTToSY.yt), PTToSY.ptAmount);

            // Burn the PT for the SY
            syOut = PTToSY.yt.redeemPY(address(this));
        } else {
            // Transfers the PT here before calling the router
            _transferFrom(PTToSY.pt, msg.sender, address(this), PTToSY.ptAmount);

            // Allow the PendleRouter to spend the PT
            _approveIfNotAllowed(PTToSY.pt, address(pendleRouter));
            // Swap the PT for SY in the LP through the pendle router
            (syOut, ) = pendleRouter.swapExactPtForSy(address(this), address(PTToSY.market), PTToSY.ptAmount, 0, createEmptyLimitOrderData());
        }

        if (crvRouterData._route[0] != address(0)) {
            // Redeem the SY for the underlying on this contract before the swap on Curve
            uint256 amountUnderlyingOut = PTToSY.sy.redeem(address(this), syOut, PTToSY.underlyingOut, 0, false);
            // Swaps the underlying for the tokenOut desired through the Curve Router
            return _curveExchange(crvRouterData._route, crvRouterData._swap_params, amountUnderlyingOut, crvRouterData._min_dy, crvRouterData._pools, crvRouterData._receiver);
        } else {
            // Redeem the SY for the underlying directly on the receiver as we don't need to go through Curve
            return PTToSY.sy.redeem(crvRouterData._receiver, syOut, PTToSY.underlyingOut, crvRouterData._min_dy, false);
        }
    }

    /**
     * @notice Swaps an ERC20 to a Pendle PT using the Curve Router then the Pendle Router.
     * @dev    Used for doing leverages ( USG => PT ) or migrations ( Other Collateral => PT )
     * @param  SYToPT  Struct containing data to perform the swaps from Underlying to PT :
     *                          - market : Address of the Pendle LP market
     *                          - pt : Address of the Pendle PT
     *                          - sy : Address of the Pendle SY
     *                          - underlyingIn : Address of the underlying ERC20 used to mint SY
     *                          - receiver : Address of the receiver of the PT
     *                          - tokenInAmount : Amount of tokenIn to swap through the Curve Router to get underlyingIn
     *                          - minPTOut : Slippage parameter on the minimum amount of PT to get
     * @param  crvRouterData  Struct containing data to perform a swap through the Curve Router
     */
    function swapTokenForPT(CurveRouterSwapNoReceiver calldata crvRouterData, PendleSYToPT calldata SYToPT) external payable returns (uint256) {
        IERC20 tokenIn = IERC20(crvRouterData._route[0]);

        // Transfers the tokenIn here
        _transferFrom(tokenIn, msg.sender, address(this), crvRouterData._amount);

        // Exchanges the tokenIn for one of the pendle market underlying
        uint256 underlyingAmount = _curveExchange(
            crvRouterData._route,
            crvRouterData._swap_params,
            crvRouterData._amount,
            // Min amount can be zero because we check slippage in _swapUnderlyingToPT
            0,
            crvRouterData._pools,
            address(this)
        );

        return _swapUnderlyingToPT(underlyingAmount, SYToPT);
    }

    function _swapUnderlyingToPT(uint256 underlyingAmount, PendleSYToPT calldata SYToPT) internal returns (uint256) {
        // Allows the SY to spend the underlyingIn
        _approveIfNotAllowed(IERC20(SYToPT.underlyingIn), address(SYToPT.sy));
        // Deposits some underlying to get some SY
        uint256 syAmount = SYToPT.sy.deposit(address(this), SYToPT.underlyingIn, underlyingAmount, 0);
        // Allows the pendle router to spend the SY
        _approveIfNotAllowed(SYToPT.sy, address(pendleRouter));

        // Exchange the SY for some PT through the Pendle Router
        (uint256 ptOut, ) = pendleRouter.swapExactSyForPt(
            SYToPT.receiver,
            address(SYToPT.market),
            syAmount,
            SYToPT.minPTOut,
            createDefaultApproxParams(),
            createEmptyLimitOrderData()
        );

        return ptOut;
    }

    function _approveIfNotAllowed(IERC20 token, address spender) internal {
        if (CHAIN_COIN != address(token) && token.allowance(address(this), address(spender)) != MAX_UINT) {
            token.forceApprove(address(spender), MAX_UINT);
        }
    }

    function _transferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (CHAIN_COIN != address(token)) {
            token.safeTransferFrom(from, to, amount);
        }
    }

    function _curveExchange(
        address[11] calldata route,
        uint256[5][5] calldata swapParams,
        uint256 amountIn,
        uint256 minOut,
        address[5] calldata pools,
        address receiver
    ) internal returns (uint256) {
        // Allows the Curve router to spend the tokenIn
        _approveIfNotAllowed(IERC20(route[0]), address(curveRouter));

        return curveRouter.exchange{value: msg.value}(route, swapParams, amountIn, minOut, pools, receiver);
    }

    function createEmptyLimitOrderData() internal pure returns (LimitOrderData memory) {}

    function createDefaultApproxParams() internal pure returns (ApproxParams memory) {
        return ApproxParams({guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1e14});
    }
}

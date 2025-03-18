// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {MintAndSwapWStable, CurveRouterSwap} from "../../interfaces/internals/tgUSD/ICurveLPLiquidator.sol";
import {ITgStable} from "../../interfaces/internals/tgUSD/ITgStable.sol";
import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";

/// @notice Liquidator - Receives collateral and liquidates it to cover a debt.
///         It uses directly the router of Curve Finance.

contract Liquidator {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);

    /// @notice Router
    address public constant ENSO_ROUTER = 0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E;

    error LiquidatorCallError();

    /// @notice
    function liquidateEnso(address assetToLiquidate, bytes memory routerData) external {
        // Approve the collateral on the Curve Router if necessary
        _approveIfNotAllowed(IERC20(assetToLiquidate), address(ENSO_ROUTER));

        (bool isRouterCallSucceed, ) = ENSO_ROUTER.call(routerData);

        // Verify the call to router was successfull
        require(isRouterCallSucceed, LiquidatorCallError());
    }

    /// @notice
    function liquidateLP(CurveRouterSwap calldata curveRouterSwap) external {
        // Approve the collateral on the Curve Router if necessary
        _approveIfNotAllowed(IERC20(curveRouterSwap._route[0]), address(CURVE_ROUTER));
        // Unwrap the LP
        // If the best route to get tgUSD doesn't pass through a wStable, we can pass fully through the Curve Router
        uint256 amountReceived = CURVE_ROUTER.exchange(
            curveRouterSwap._route,
            curveRouterSwap._swap_params,
            curveRouterSwap._amount,
            curveRouterSwap._min_dy,
            curveRouterSwap._pools,
            curveRouterSwap._receiver
        );
    }

    function _approveIfNotAllowed(IERC20 erc20, address spender) internal {
        if (erc20.allowance(address(this), spender) != (type(uint256).max)) {
            erc20.approve(spender, type(uint256).max);
        }
    }
}

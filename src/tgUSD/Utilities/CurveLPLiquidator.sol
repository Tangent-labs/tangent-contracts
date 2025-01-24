// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {RemoveLiquidityCollateral, CurveRouterSwap} from "../../interfaces/internals/tgUSD/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";

/// @notice CurveLPLiquidator - Proxy allowing to liquidate collateral that are LP from Curve Finance.
///         It uses directly the router of Curve Finance.

contract CurveLPLiquidator {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);

    /// @notice
    function liquidateLP(CurveRouterSwap calldata curveRouterSwap, uint256 debtToCover) external {
        uint256 amountIn = curveRouterSwap._amount;
        IERC20 collateral = IERC20(curveRouterSwap._route[0]);
        if (collateral.allowance(address(this), address(CURVE_ROUTER)) != (type(uint256).max)) {
            collateral.approve(address(CURVE_ROUTER), type(uint256).max);
        }
        // Swap tokens
        CURVE_ROUTER.exchange(
            curveRouterSwap._route,
            curveRouterSwap._swap_params,
            curveRouterSwap._amount,
            curveRouterSwap._min_dy,
            curveRouterSwap._pools,
            curveRouterSwap._receiver
        );
    }
}

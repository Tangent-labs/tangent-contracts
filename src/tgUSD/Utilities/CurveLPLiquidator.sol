// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {RemoveLiquidityCollateral, CurveRouterSwap} from "../../interfaces/internals/tgUSD/ICurveLPLiquidator.sol";
import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";

contract CurveLPLiquidator {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);

    function liquidateLP(RemoveLiquidityCollateral calldata removeLiquidity, CurveRouterSwap calldata curveRouterSwap, uint256 debtToCover) external {
        _removeLiquidityCollateral(removeLiquidity);
        _swapTokensThroughRouter(curveRouterSwap);
    }

    function _removeLiquidityCollateral(RemoveLiquidityCollateral calldata removeLiquidity) internal {
        ICurveStableSwapNG lp = ICurveStableSwapNG(removeLiquidity.lpToLiquidate);

        // Unwrap the LP token

        // Remove both coins in balance
        if (removeLiquidity.minAmounts[0] != 0 && removeLiquidity.minAmounts[1] != 0) {
            console.log("Remove double coin");
            uint256[2] memory tokensOut = lp.remove_liquidity(removeLiquidity.amountToLiquidate, removeLiquidity.minAmounts);
        }
        // Remove only one coin from the LP
        else {
            console.log("Remove one coin");
            int128 tokenOutId = removeLiquidity.minAmounts[0] != 0 ? int128(0) : int128(1);
            uint256 amountOut = lp.remove_liquidity_one_coin(removeLiquidity.amountToLiquidate, tokenOutId, removeLiquidity.minAmounts[uint256(int256(tokenOutId))]);
        }
    }

    function _swapTokensThroughRouter(CurveRouterSwap calldata curveRouterSwap) internal {
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

    // function decode(bytes memory data) private pure returns (uint8 withdrawType, uint256 productAmount, bytes3 color) {
    //     assembly {
    //         // load 32 bytes into `selector` from `data` skipping the first 32 bytes
    //         selector := mload(add(data, 32))
    //         productAmount := mload(add(data, 64))
    //         color := mload(add(data, 96))
    //     }
    // }
}

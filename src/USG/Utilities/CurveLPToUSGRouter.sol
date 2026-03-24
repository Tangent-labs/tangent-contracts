// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  CurveLPToUSGRouter
/// @notice Stateless router called by ZappingProxy during liquidation.
///         Converts a Curve LP token → USG in up to 3 Curve steps:
///           1. remove_liquidity_one_coin(LP pool) → withdrawn coin
///           2. (optional) exchange(withdrawn coin → USDC) on an intermediate pool
///           3. exchange(USDC → USG) on the USG-USDC pool
/// @dev    minAmountOut is set to 0 in all Curve calls because slippage is enforced
///         downstream by the ZappingProxy, which checks `minUsgOut` (from PostLiquidate)
///         on the final USG balance received. This makes per-step slippage checks redundant.
contract CurveLPToUSGRouter {
    using SafeERC20 for IERC20;

    struct SwapParams {
        address lpToken; // Curve LP / pool address (StableSwapNG: pool == LP)
        uint256 lpAmount; // Amount of LP to convert
        int128 withdrawIndex; // Index of the coin to withdraw via remove_liquidity_one_coin
        address withdrawnToken; // Address of the withdrawn coin
        address midPool; // Curve pool for withdrawn → USDC (address(0) if withdrawn == USDC)
        int128 midFromIndex; // Index of withdrawn coin in midPool
        int128 midToIndex; // Index of USDC in midPool
        address usdc; // USDC token address (ignored when midPool == address(0))
        address usgPool; // Curve pool for USDC → USG exchange
        int128 usdcIndexInUsgPool; // Index of USDC in usgPool
        int128 usgIndexInUsgPool; // Index of USG in usgPool
        address usg; // USG token address
        address receiver; // Address to receive the USG (the liquidator)
    }

    /// @notice Swap collateral LP → USG via up to 3 Curve steps.
    function swap(SwapParams calldata p) external {
        // Pull LP from caller (ZappingProxy has approved this contract)
        IERC20(p.lpToken).safeTransferFrom(msg.sender, address(this), p.lpAmount);

        // Step 1: remove_liquidity_one_coin → withdrawnToken
        ICurveStableSwapNG(p.lpToken).remove_liquidity_one_coin(p.lpAmount, p.withdrawIndex, 0);

        // Step 2 (optional): exchange withdrawnToken → USDC on midPool
        address tokenForUsgSwap;
        if (p.midPool != address(0)) {
            uint256 withdrawnBal = IERC20(p.withdrawnToken).balanceOf(address(this));
            IERC20(p.withdrawnToken).forceApprove(p.midPool, withdrawnBal);
            ICurveStableSwapNG(p.midPool).exchange(p.midFromIndex, p.midToIndex, withdrawnBal, 0);
            tokenForUsgSwap = p.usdc;
        } else {
            tokenForUsgSwap = p.withdrawnToken;
        }

        // Step 3: exchange USDC → USG on usgPool
        uint256 usdcBal = IERC20(tokenForUsgSwap).balanceOf(address(this));
        IERC20(tokenForUsgSwap).forceApprove(p.usgPool, usdcBal);
        ICurveStableSwapNG(p.usgPool).exchange(p.usdcIndexInUsgPool, p.usgIndexInUsgPool, usdcBal, 0);

        // Step 4: send USG to receiver
        uint256 usgBal = IERC20(p.usg).balanceOf(address(this));
        IERC20(p.usg).safeTransfer(p.receiver, usgBal);
    }
}

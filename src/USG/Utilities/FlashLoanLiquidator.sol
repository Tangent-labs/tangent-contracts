// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {LiquidateIn, PostLiquidate} from "../../interfaces/internals/USG/IMarketCore.sol";
import {IMarketExternalActions} from "../../interfaces/internals/USG/IMarketExternalActions.sol";
import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {LightOwnable} from "./abstract/LightOwnable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolV3} from "../../interfaces/externals/Aave/IPoolV3.sol";
import {IFlashLoanSimpleReceiver} from "../../interfaces/externals/Aave/IFlashLoanSimpleReceiver.sol";

/// @title  FlashLoanLiquidator
/// @notice Liquidates unhealthy positions on Tangent markets using Aave V3 flash loans.
///
///         Flow:
///         1. Flash-borrow USDC from Aave V3
///         2. Swap USDC → USG via Curve pool
///         3. Call market.liquidate() with router=address(0) → receive collateral LP
///         4. remove_liquidity_one_coin on the collateral LP pool → intermediate token
///         5. (Optional) exchange intermediate → USDC on a second Curve pool
///         6. Repay Aave flash loan (USDC + premium)
///         7. Profit stays in the contract (owner can withdraw)
contract FlashLoanLiquidator is IFlashLoanSimpleReceiver, LightOwnable {
    using SafeERC20 for IERC20;

    IPoolV3 public immutable AAVE_POOL;
    IERC20 public immutable USDC;

    /// @notice Parameters for the liquidation, encoded in the flash loan callback
    struct LiquidationParams {
        address market;
        address account;
        uint256 collatAmount;
        uint256 maxUsgToBurn;
        address usg;
        ICurveStableSwapNG usgUsdcPool;
        int128 usdcIndexInPool;
        int128 usgIndexInPool;
        uint256 minUsgFromSwap;     // Minimum USG expected from the USDC → USG swap (sandwich protection)
        // --- Curve route: collateral LP → USDC ---
        address collatToken;        // Collateral LP token (== Curve pool for StableSwapNG)
        int128 withdrawCoinIndex;   // Index of coin to withdraw via remove_liquidity_one_coin
        address swapPool;           // Optional: Curve pool for intermediate → USDC (address(0) if withdrawal gives USDC directly)
        address swapTokenIn;        // Intermediate token address (for approval, only used if swapPool != address(0))
        int128 swapFromIndex;       // From-index in swapPool
        int128 swapToIndex;         // To-index (USDC) in swapPool
    }

    error OnlyAavePool();
    error OnlySelf();
    error UnprofitableLiquidation();

    constructor(address _aavePool, address _usdc, address _owner) {
        AAVE_POOL = IPoolV3(_aavePool);
        USDC = IERC20(_usdc);
        _transferOwnership(_owner);
    }

    /// @notice Initiate a flash loan liquidation
    function liquidate(uint256 usdcAmount, LiquidationParams calldata params) external {
        AAVE_POOL.flashLoanSimple(address(this), address(USDC), usdcAmount, abi.encode(params), 0);
    }

    /// @notice Aave V3 flash loan callback
    function executeOperation(address, uint256 amount, uint256 premium, address initiator, bytes calldata params) external returns (bool) {
        require(msg.sender == address(AAVE_POOL), OnlyAavePool());
        require(initiator == address(this), OnlySelf());

        LiquidationParams memory p = abi.decode(params, (LiquidationParams));

        // Step 1: Swap USDC → USG via Curve pool
        USDC.forceApprove(address(p.usgUsdcPool), amount);
        p.usgUsdcPool.exchange(p.usdcIndexInPool, p.usgIndexInPool, amount, p.minUsgFromSwap);

        // Step 2: Liquidate — collateral LP sent directly to this contract
        IMarketExternalActions(p.market).liquidate(
            LiquidateIn({
                account: p.account,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: p.collatAmount,
                    minUsgOut: 0,
                    maxUsgToBurn: p.maxUsgToBurn,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );

        // Step 3: Remove liquidity from collateral LP pool → intermediate coin
        uint256 collatBal = IERC20(p.collatToken).balanceOf(address(this));
        if (collatBal > 0) {
            ICurveStableSwapNG(p.collatToken).remove_liquidity_one_coin(collatBal, p.withdrawCoinIndex, 0);

            // Step 4 (optional): Exchange intermediate → USDC on a second Curve pool
            if (p.swapPool != address(0)) {
                uint256 intermediateBal = IERC20(p.swapTokenIn).balanceOf(address(this));
                IERC20(p.swapTokenIn).forceApprove(p.swapPool, intermediateBal);
                ICurveStableSwapNG(p.swapPool).exchange(p.swapFromIndex, p.swapToIndex, intermediateBal, 0);
            }
        }

        // Step 5: Repay Aave
        uint256 amountOwed = amount + premium;
        require(USDC.balanceOf(address(this)) >= amountOwed, UnprofitableLiquidation());
        USDC.forceApprove(address(AAVE_POOL), amountOwed);

        return true;
    }

    /// @notice Withdraw any token stuck in the contract
    function withdrawTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICurveStableSwapNG} from "../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {LiquidateIn, PostLiquidate} from "../../../src/interfaces/internals/USG/IMarketCore.sol";
import {IMarketExternalActions} from "../../../src/interfaces/internals/USG/IMarketExternalActions.sol";
import {ZapStruct} from "../../../src/interfaces/internals/ICommonStruct.sol";
import {LightOwnable} from "../../../src/USG/Utilities/abstract/LightOwnable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolV3} from "../../../src/interfaces/externals/Aave/IPoolV3.sol";
import {IFlashLoanSimpleReceiver} from "../../../src/interfaces/externals/Aave/IFlashLoanSimpleReceiver.sol";

/// @title  FlashLoanLiquidatorGeneric
/// @notice Simplified test version of a flash-loan liquidator with generic router support.
/// @dev    This is a test/example contract. The production contract is in
///         src/USG/Utilities/FlashLoanLiquidator.sol and uses Curve-specific routing.
///
///         Flow:
///         1. Flash-borrow USDC from Aave V3
///         2. Swap USDC → USG via Curve pool
///         3. Call market.liquidate() with router=address(0) → receive collateral
///         4. Swap collateral → USDC via external router (e.g. Enso)
///         5. Repay Aave flash loan (USDC + premium)
///         6. Profit stays in the contract (owner can withdraw)
contract FlashLoanLiquidatorGeneric is IFlashLoanSimpleReceiver, LightOwnable {
    using SafeERC20 for IERC20;

    IPoolV3 public immutable AAVE_POOL;
    IERC20 public immutable USDC;

    /// @notice Parameters for the liquidation, encoded in the flash loan callback
    struct LiquidationParams {
        address market; // Tangent market to liquidate on
        address account; // Account to liquidate
        uint256 collatAmount; // Collateral amount to liquidate
        uint256 maxUsgToBurn; // Max USG to burn from this contract
        address usg; // USG token address
        ICurveStableSwapNG usgUsdcPool; // Curve pool for USDC <-> USG swap
        int128 usdcIndexInPool; // Index of USDC in the Curve pool
        int128 usgIndexInPool; // Index of USG in the Curve pool
        address collatToken; // Collateral token address
        address collatToUsdcRouter; // Router for collateral → USDC swap (address(0) to skip)
        bytes collatToUsdcSwapData; // Calldata for collateral → USDC swap
    }

    error OnlyAavePool();
    error OnlySelf();
    error UnprofitableLiquidation();
    error SwapFailed();

    constructor(address _aavePool, address _usdc, address _owner) {
        AAVE_POOL = IPoolV3(_aavePool);
        USDC = IERC20(_usdc);
        _transferOwnership(_owner);
    }

    /// @notice Initiate a flash loan liquidation
    /// @param usdcAmount Amount of USDC to flash-borrow from Aave
    /// @param params     Encoded liquidation parameters
    function liquidate(uint256 usdcAmount, LiquidationParams calldata params) external {
        AAVE_POOL.flashLoanSimple(address(this), address(USDC), usdcAmount, abi.encode(params), 0);
    }

    /// @notice Aave V3 flash loan callback — executes the liquidation
    function executeOperation(address, uint256 amount, uint256 premium, address initiator, bytes calldata params) external returns (bool) {
        require(msg.sender == address(AAVE_POOL), OnlyAavePool());
        require(initiator == address(this), OnlySelf());

        LiquidationParams memory p = abi.decode(params, (LiquidationParams));

        // Step 1: Swap USDC → USG via Curve pool
        USDC.forceApprove(address(p.usgUsdcPool), amount);
        p.usgUsdcPool.exchange(p.usdcIndexInPool, p.usgIndexInPool, amount, 0);

        // Step 2: Liquidate — collateral sent directly to this contract (router = address(0))
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

        // Step 3: Swap collateral → USDC via external router
        if (p.collatToUsdcRouter != address(0)) {
            uint256 collatBalance = IERC20(p.collatToken).balanceOf(address(this));
            IERC20(p.collatToken).forceApprove(p.collatToUsdcRouter, collatBalance);
            (bool ok,) = p.collatToUsdcRouter.call(p.collatToUsdcSwapData);
            require(ok, SwapFailed());
        }

        // Step 4: Repay Aave
        uint256 amountOwed = amount + premium;
        require(USDC.balanceOf(address(this)) >= amountOwed, UnprofitableLiquidation());
        USDC.forceApprove(address(AAVE_POOL), amountOwed);

        return true;
    }

    /// @notice Withdraw any token stuck in the contract (rescue / profit withdrawal)
    function withdrawTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}

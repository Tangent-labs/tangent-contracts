// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  Example B — Flash Loan Liquidation via Aave V3
 * @notice Demonstrates the full flash-loan liquidation pattern:
 *         1. Flash-borrow USDC from Aave V3
 *         2. Swap USDC → USG via the Curve USG-USDC pool
 *         3. Call market.liquidate() with router=address(0) → receive collateral
 *         4. Swap collateral → USDC (simulated in test via deal())
 *         5. Repay Aave flash loan + premium
 *         6. Profit remains in the FlashLoanLiquidatorGeneric contract
 *
 *         The collateral → USDC swap is simulated with deal() in this test
 *         because the fork environment doesn't have a live DEX aggregator.
 *         In production, Enso API would provide the swap route.
 */
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Curve/HLPManipulator.sol";

import "./FlashLoanLiquidatorGeneric.sol";
import "../../../src/interfaces/externals/Aave/IPoolV3.sol";

contract ExampleB_FlashLoanLiquidatorGeneric is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexFxnLP public hDeposit;
    HLPManipulator public hLpManipulator;

    FlashLoanLiquidatorGeneric public flashLoanLiquidator;
    ICurveStableSwapNG public usgUsdcPool;

    address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    uint256 public constant COLLAT_DEPOSITED = 10_000 ether;
    uint256 public constant USG_BORROWED = 8_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market, usg, marketViewer);
        hLpManipulator = new HLPManipulator(usr2);

        // --- Create position: usr1 deposits 10000 LP, borrows 8000 USG ---
        hDeposit.depositAndBorrow(COLLAT_DEPOSITED, USG_BORROWED, false);

        // --- Deploy FlashLoanLiquidatorGeneric ---
        flashLoanLiquidator = new FlashLoanLiquidatorGeneric(AAVE_V3_POOL, address(AddrClassicERC20.USDC), address(this));

        // --- Get USG-USDC Curve pool (deployed by test framework) ---
        usgUsdcPool = lpDeploymentContext.USGLPs("USG-USDC");
    }

    // ---------------------------------------------------------------
    //  Full flash loan liquidation flow
    // ---------------------------------------------------------------
    function test_flashLoan_liquidation_full_flow() external {
        // 1. Crash LP price to make position liquidable
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);
        skip(200);

        // 2. Verify position is liquidable
        uint256 hr = marketViewer.healthRatio(address(market), usr1);
        assertLt(hr, 1 ether, "Position should be liquidable after price crash");

        // 3. Calculate USDC amount needed for flash loan
        uint256 userDebt = marketViewer.userDebt(market, usr1);
        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 collatValue = (market.collatOracle().latestAnswer(true) * collatAmount) / (10 ** collatToken.decimals());
        uint256 liquidationFee = collatValue > userDebt ? ((collatValue - userDebt) * market.liquidationFee()) / 100_000 : 0;
        uint256 usgNeeded = userDebt + liquidationFee;

        // USDC amount: USG is 18 decimals, USDC is 6 decimals
        // Add 5% buffer for swap slippage
        uint256 usdcFlashAmount = (usgNeeded / 1e12) * 105 / 100;

        // 4. Build liquidation params
        FlashLoanLiquidatorGeneric.LiquidationParams memory params = FlashLoanLiquidatorGeneric.LiquidationParams({
            market: address(market),
            account: usr1,
            collatAmount: collatAmount,
            maxUsgToBurn: type(uint256).max,
            usg: address(usg),
            usgUsdcPool: usgUsdcPool,
            usdcIndexInPool: 0,
            usgIndexInPool: 1,
            collatToken: address(collatToken),
            collatToUsdcRouter: address(0),
            collatToUsdcSwapData: ""
        });

        // 5. Pre-fund the contract with enough USDC to cover repayment
        //    (simulates the collateral → USDC swap output)
        uint128 premium = IPoolV3(AAVE_V3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 repayAmount = usdcFlashAmount + (usdcFlashAmount * premium) / 10_000;
        deal(address(AddrClassicERC20.USDC), address(flashLoanLiquidator), repayAmount + 100e6);

        // 6. Execute flash loan liquidation
        flashLoanLiquidator.liquidate(usdcFlashAmount, params);

        // 7. Verify outcomes
        assertEq(market.collateralBalances(usr1), 0, "Position should be fully liquidated");
        assertEq(marketViewer.userDebt(market, usr1), 0, "Debt should be fully repaid");

        // Liquidator contract received the collateral
        assertGt(collatToken.balanceOf(address(flashLoanLiquidator)), 0, "FlashLoanLiquidatorGeneric should hold collateral");

        // USDC profit remains in the contract
        uint256 usdcBalance = AddrClassicERC20.USDC.balanceOf(address(flashLoanLiquidator));
        assertGt(usdcBalance, 0, "FlashLoanLiquidatorGeneric should have USDC profit");
    }

    // ---------------------------------------------------------------
    //  Owner can withdraw profit
    // ---------------------------------------------------------------
    function test_owner_can_withdraw_profit() external {
        deal(address(AddrClassicERC20.USDC), address(flashLoanLiquidator), 1000e6);

        uint256 balBefore = AddrClassicERC20.USDC.balanceOf(address(this));
        flashLoanLiquidator.withdrawTokens(IERC20(address(AddrClassicERC20.USDC)), address(this), 1000e6);
        uint256 balAfter = AddrClassicERC20.USDC.balanceOf(address(this));

        assertEq(balAfter - balBefore, 1000e6, "Owner should receive withdrawn USDC");
    }

    // ---------------------------------------------------------------
    //  Non-owner cannot withdraw
    // ---------------------------------------------------------------
    function test_nonOwner_cannot_withdraw() external {
        deal(address(AddrClassicERC20.USDC), address(flashLoanLiquidator), 1000e6);

        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        flashLoanLiquidator.withdrawTokens(IERC20(address(AddrClassicERC20.USDC)), usr1, 1000e6);
    }

    // ---------------------------------------------------------------
    //  Reverts if position is healthy
    // ---------------------------------------------------------------
    function test_revert_flashLoan_on_healthy_position() external {
        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 usdcFlashAmount = 5000e6;

        FlashLoanLiquidatorGeneric.LiquidationParams memory params = FlashLoanLiquidatorGeneric.LiquidationParams({
            market: address(market),
            account: usr1,
            collatAmount: collatAmount,
            maxUsgToBurn: type(uint256).max,
            usg: address(usg),
            usgUsdcPool: usgUsdcPool,
            usdcIndexInPool: 0,
            usgIndexInPool: 1,
            collatToken: address(collatToken),
            collatToUsdcRouter: address(0),
            collatToUsdcSwapData: ""
        });

        deal(address(AddrClassicERC20.USDC), address(flashLoanLiquidator), 10000e6);

        vm.expectRevert();
        flashLoanLiquidator.liquidate(usdcFlashAmount, params);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  Example A — Liquidation by swapping collateral for USG via ZappingProxy
 * @notice Reproduces the scenario described in the liquidation user manual:
 *         - Market: ConvexFxnLP (collateral = LP USDC/fxUSD)
 *         - Position: 10 000 LP tokens deposited, 8 000 USG borrowed
 *         - The HR drops below 1 after LP price goes down (EMA update)
 *         - A liquidator swaps the collateral for USG through the ZappingProxy router
 *
 *         In a real scenario the `ZapStruct.router` / `ZapStruct.routerCall` would
 *         come from the Enso API.  Here we simulate the swap by using address(0)
 *         (direct mode) and pre-funding the liquidator with USG, because the test
 *         environment does not have a live DEX router.
 */
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract ExampleA_LiquidateWithSwap is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexFxnLP public hDeposit;
    HLPManipulator public hLpManipulator;

    uint256 public constant COLLAT_DEPOSITED = 10_000 ether;
    uint256 public constant USG_BORROWED = 8_000 ether;

    function setUp() public {
        // --- Deploy market with LP USDC/fxUSD as collateral ---
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        // --- Helpers ---
        hDeposit = new HDepositConvexFxnLP(usr1, market, usg, marketViewer);
        hLpManipulator = new HLPManipulator(usr2);

        // --- usr1 deposits 10 000 LP and borrows 8 000 USG ---
        hDeposit.depositAndBorrow(COLLAT_DEPOSITED, USG_BORROWED, false);
    }

    // ---------------------------------------------------------------
    //  Step 1 — Verify the position is NOT liquidable initially
    // ---------------------------------------------------------------
    function test_position_is_healthy_before_price_drop() external view {
        uint256 hr = marketViewer.healthRatio(address(market), usr1);
        assertGe(hr, 1 ether, "HR should be >= 1 before any price move");
    }

    // ---------------------------------------------------------------
    //  Step 2 — Full liquidation after collateral loses value
    //           (simulates Example A from the manual)
    // ---------------------------------------------------------------
    function test_exampleA_full_liquidation_after_price_drop() external {
        // 1. Verify position is healthy
        uint256 hrBefore = marketViewer.healthRatio(address(market), usr1);
        assertGe(hrBefore, 1 ether, "Position should be healthy initially");

        // 2. Crash the LP price by unbalancing the pool
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);

        // 3. EMA oracle needs time to reflect the new price
        skip(200);

        // 4. Now the position should be liquidable
        uint256 hrAfter = marketViewer.healthRatio(address(market), usr1);
        assertLt(hrAfter, 1 ether, "HR should be < 1 after price crash + EMA update");

        // 5. Prepare the liquidator (usr2)
        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 userDebt = marketViewer.userDebt(market, usr1);
        uint256 collatValue = (market.collatOracle().latestAnswer(true) * collatAmount) / (10 ** collatToken.decimals());
        uint256 liquidationFee = ((collatValue - userDebt) * market.liquidationFee()) / 100_000;

        deal(address(usg), usr2, userDebt + liquidationFee);

        // 6. Execute liquidation (direct mode: router = address(0))
        vm.startPrank(usr2);
        usg.approve(address(market), type(uint256).max);

        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: collatAmount,
                    minUsgOut: 0,
                    maxUsgToBurn: type(uint256).max,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        vm.stopPrank();

        // 7. Verify the position is fully liquidated
        assertEq(market.collateralBalances(usr1), 0, "usr1 collateral should be 0");
        assertEq(marketViewer.userDebt(market, usr1), 0, "usr1 debt should be 0");

        // 8. Liquidator received the collateral
        assertGt(collatToken.balanceOf(usr2), 0, "Liquidator should have received collateral");
    }

    // ---------------------------------------------------------------
    //  Step 3 — Partial liquidation
    // ---------------------------------------------------------------
    function test_exampleA_partial_liquidation() external {
        // Crash price
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);
        skip(200);

        assertLt(marketViewer.healthRatio(address(market), usr1), 1 ether, "Position should be liquidable");

        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 halfCollat = collatAmount / 2;

        // Fund the liquidator
        deal(address(usg), usr2, marketViewer.userDebt(market, usr1));

        vm.startPrank(usr2);
        usg.approve(address(market), type(uint256).max);

        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: halfCollat,
                    minUsgOut: 0,
                    maxUsgToBurn: type(uint256).max,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        vm.stopPrank();

        // Position still exists but with reduced collateral and debt
        assertApproxEqAbs(market.collateralBalances(usr1), collatAmount - halfCollat, 1, "Half collateral should remain");
        assertGt(marketViewer.userDebt(market, usr1), 0, "Debt should still exist after partial liq");
    }

    // ---------------------------------------------------------------
    //  Revert: cannot liquidate a healthy position
    // ---------------------------------------------------------------
    function test_revert_liquidate_healthy_position() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: COLLAT_DEPOSITED,
                    minUsgOut: 0,
                    maxUsgToBurn: type(uint256).max,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        vm.stopPrank();
    }
}

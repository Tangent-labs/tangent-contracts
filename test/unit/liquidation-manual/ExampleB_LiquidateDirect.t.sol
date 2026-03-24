// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  Example B — Liquidation with direct collateral retrieval (flash-loan pattern)
 * @notice Reproduces the scenario described in the liquidation user manual:
 *         - The liquidator already holds USG (e.g. from a flash loan)
 *         - Calls `liquidate()` with `router = address(0)` → collateral sent directly
 *         - Then the liquidator can swap the collateral off-chain via Enso or any DEX
 *
 *         In production a FlashLoanLiquidator contract would:
 *           1. Flash-borrow USDC from Aave
 *           2. Swap USDC → USG via Curve pool
 *           3. Call market.liquidate() with router=address(0)
 *           4. Swap collateral → USDC via Enso
 *           5. Repay flash loan + fee
 *           6. Keep surplus as profit
 */
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract ExampleB_LiquidateDirect is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexFxnLP public hDeposit;
    HLPManipulator public hLpManipulator;

    uint256 public constant COLLAT_DEPOSITED = 10_000 ether;
    uint256 public constant USG_BORROWED = 8_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market, usg, marketViewer);
        hLpManipulator = new HLPManipulator(usr2);

        hDeposit.depositAndBorrow(COLLAT_DEPOSITED, USG_BORROWED, false);
    }

    // ---------------------------------------------------------------
    //  Flash-loan pattern: liquidator has USG, gets collateral directly
    // ---------------------------------------------------------------
    function test_exampleB_direct_liquidation_with_preexisting_USG() external {
        // 1. Crash the LP price
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);
        skip(200);

        assertLt(marketViewer.healthRatio(address(market), usr1), 1 ether, "Position should be liquidable");

        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 userDebt = marketViewer.userDebt(market, usr1);
        uint256 collatValue = (market.collatOracle().latestAnswer(true) * collatAmount) / (10 ** collatToken.decimals());
        uint256 liquidationFee = ((collatValue - userDebt) * market.liquidationFee()) / 100_000;

        // 2. Simulate flash loan: give usr2 exactly the USG needed
        uint256 usgNeeded = userDebt + liquidationFee;
        deal(address(usg), usr2, usgNeeded);

        uint256 collatBefore = collatToken.balanceOf(usr2);

        // 3. Liquidate with router = address(0) → collateral sent directly to msg.sender
        vm.startPrank(usr2);
        usg.approve(address(market), type(uint256).max);

        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: collatAmount,
                    minUsgOut: 0,
                    maxUsgToBurn: usgNeeded,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        vm.stopPrank();

        // 4. Verify outcomes
        assertEq(market.collateralBalances(usr1), 0, "Position fully liquidated");
        assertEq(marketViewer.userDebt(market, usr1), 0, "Debt fully repaid");

        uint256 collatReceived = collatToken.balanceOf(usr2) - collatBefore;
        assertEq(collatReceived, collatAmount, "Liquidator received all collateral");
    }

    // ---------------------------------------------------------------
    //  Verify liquidation fee is sent to feeTreasury
    // ---------------------------------------------------------------
    function test_exampleB_liquidation_fee_goes_to_treasury() external {
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);
        skip(200);

        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 userDebt = marketViewer.userDebt(market, usr1);
        uint256 collatValue = (market.collatOracle().latestAnswer(true) * collatAmount) / (10 ** collatToken.decimals());
        uint256 liquidationFee = ((collatValue - userDebt) * market.liquidationFee()) / 100_000;

        uint256 treasuryBefore = usg.balanceOf(feeTreasury);

        deal(address(usg), usr2, userDebt + liquidationFee);

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

        uint256 treasuryAfter = usg.balanceOf(feeTreasury);
        assertEq(treasuryAfter - treasuryBefore, liquidationFee, "Fee should be minted to treasury");
    }

    // ---------------------------------------------------------------
    //  maxUsgToBurn caps the USG spent by the liquidator
    // ---------------------------------------------------------------
    function test_exampleB_maxUsgToBurn_caps_spending() external {
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);
        skip(200);

        uint256 collatAmount = market.collateralBalances(usr1);
        uint256 userDebt = marketViewer.userDebt(market, usr1);

        deal(address(usg), usr2, userDebt * 2);

        vm.startPrank(usr2);
        usg.approve(address(market), type(uint256).max);

        // With maxUsgToBurn = 0 and no router, the liquidation should revert
        vm.expectRevert();
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: collatAmount,
                    minUsgOut: 0,
                    maxUsgToBurn: 0,
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

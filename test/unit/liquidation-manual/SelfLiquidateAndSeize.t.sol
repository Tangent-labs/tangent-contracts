// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  Self-Liquidation & Seize Collateral (Bad Debt) examples
 * @notice Covers the 2 other liquidation modes from the manual:
 *
 *         selfLiquidate — The position owner liquidates their own position.
 *           - Always callable (no HR requirement)
 *           - The owner repays debt and recovers leftover collateral
 *
 *         seizeCollateral — Anyone can call when collateral value < debt (bad debt).
 *           - Collateral is sent to the DAO treasury
 *           - Debt becomes bad debt on the market
 */
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract SelfLiquidateAndSeize is MarketDeploymentContext {
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

    // ===============================================================
    //                      SELF-LIQUIDATION
    // ===============================================================

    /**
     * @notice Self-liquidate entire position when user has USG to repay debt.
     *         The user gets back their collateral minus debt repaid.
     */
    function test_selfLiquidate_full_position() external {
        vm.startPrank(usr1);

        uint256 debt = marketViewer.userDebt(market, usr1);

        market.selfLiquidate(
            SelfLiquidateIn({
                collatAmountToLiquidate: COLLAT_DEPOSITED,
                usgToRepay: type(uint256).max,
                maxUsgToBurn: type(uint256).max,
                minUsgOut: debt,
                isReceiptOut: false
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );

        assertEq(market.collateralBalances(usr1), 0, "All collateral removed");
        assertEq(marketViewer.userDebt(market, usr1), 0, "Debt fully repaid");

        vm.stopPrank();
    }

    /**
     * @notice Self-liquidate partial position — remove some collateral and repay proportional debt.
     *         With 8_000 USG borrowed, repaying half leaves 4_000 remaining (> minimumLoan of 3_000).
     */
    function test_selfLiquidate_partial_position() external {
        vm.startPrank(usr1);

        uint256 debtBefore = marketViewer.userDebt(market, usr1);
        uint256 halfCollat = COLLAT_DEPOSITED / 2;
        uint256 halfDebt = debtBefore / 2;

        market.selfLiquidate(
            SelfLiquidateIn({
                collatAmountToLiquidate: halfCollat,
                usgToRepay: halfDebt,
                maxUsgToBurn: type(uint256).max,
                minUsgOut: 0,
                isReceiptOut: false
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );

        assertApproxEqAbs(market.collateralBalances(usr1), COLLAT_DEPOSITED - halfCollat, 1, "Half collateral removed");
        assertGt(marketViewer.userDebt(market, usr1), 0, "Some debt remains");

        vm.stopPrank();
    }

    // ===============================================================
    //                      SEIZE COLLATERAL (BAD DEBT)
    // ===============================================================

    /**
     * @notice seizeCollateral reverts when collateral value > debt (no bad debt).
     */
    function test_seize_reverts_when_no_bad_debt() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionWithoutBadDebt.selector));
        market.seizeCollateral(usr1);
        vm.stopPrank();
    }

    /**
     * @notice seizeCollateral succeeds when collateral value < debt.
     *         Uses WETH/frxETH market which can create bad debt more easily.
     */
    function test_seize_collateral_on_bad_debt_position() external {
        // Deploy a separate market with ETH-based collateral for easier bad debt scenario
        IERC20Metadata ethCollatToken = AddrCurveStableLP.WETH_frxETH;
        ConvexCrvLPMarket ethMarket = deployConvexCurveLPMarket(ethCollatToken);

        HDepositConvexCrvLP hDepositEth = new HDepositConvexCrvLP(usr3, ethMarket, usg, marketViewer);
        HLPManipulator hLpManipulatorEth = new HLPManipulator(usr3);

        uint256 ethCollat = 6 ether;
        uint256 ethDebt = 10_000 ether;

        skip(1 hours);
        hDepositEth.depositAndBorrow(ethCollat, ethDebt, false);

        // Crash the LP price heavily to create bad debt (value < debt)
        hLpManipulatorEth.dumpCrvPool(AddrCurveStableLP.WETH_frxETH, 1, 0, 2_400 ether);

        // Wait for EMA oracle to update
        skip(30 days);

        // Confirm bad debt: position value < debt
        assertLt(
            marketViewer.positionValue(ethMarket, usr3),
            marketViewer.userDebt(ethMarket, usr3),
            "Position value should be less than debt (bad debt)"
        );

        // Anyone can seize — collateral goes to DAO treasury
        uint256 treasuryCollatBefore = ethCollatToken.balanceOf(controlTower.feeTreasury());

        vm.prank(usr4);
        ethMarket.seizeCollateral(usr3);

        // Verify outcomes
        assertEq(ethMarket.collateralBalances(usr3), 0, "Collateral seized");
        assertEq(marketViewer.userDebt(ethMarket, usr3), 0, "User debt cleared");
        assertGt(ethMarket.badDebt(), 0, "Bad debt recorded on market");

        uint256 treasuryCollatAfter = ethCollatToken.balanceOf(controlTower.feeTreasury());
        assertEq(treasuryCollatAfter - treasuryCollatBefore, ethCollat, "Collateral sent to DAO treasury");
    }
}

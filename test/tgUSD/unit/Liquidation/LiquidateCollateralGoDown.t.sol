// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
contract LiquidateCollateralGoDown is ConvexCurveContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_FXUSD;
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1, market);
    }

    function test_liquidate_all_after_collateral_loses_value() external {
        hDeposit.depositAndBorrow(10_000 ether, 8_000 ether, true, address(0));

        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, ILiquidator(address(0)));
        vm.stopPrank();

        // Unbalance USDC_FXUSD LP for destroying the peg and so the price_oracle
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_FXUSD, 1, 0, 5_000_000 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, ILiquidator(address(0)));

        skip(200);

        deal(address(tgUsd), usr1, market.positionDebt(usr1));

        verifyLostERC20(tgUsd, usr1, market.positionDebt(usr1), "tgUSD burnt from sender");
        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "tgUSD burnt from sender");
        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, MAX_UINT, ILiquidator(address(0)));
        assertERC20Tracking();

        assertEq(market.positionDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        assertEq(market.lastIR(), 0);

        vm.stopPrank();
    }

    function test_liquidate_partial_after_collateral_loses_value() external {
        hDeposit.depositAndBorrow(10_000 ether, 8_000 ether, true, address(0));

        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, 4_000 ether, ILiquidator(address(0)));
        vm.stopPrank();

        // Unbalance USDC_FXUSD LP for destroying the peg and so the price_oracle
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_FXUSD, 1, 0, 5_000_000 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, 4_000 ether, ILiquidator(address(0)));
        vm.stopPrank();

        skip(200);

        vm.startPrank(usr1);
        deal(address(tgUsd), usr1, market.positionDebt(usr1));

        verifyLostERC20(tgUsd, usr1, 4_000 ether, "tgUSD burnt from sender");
        verifyReceiveERC20(collatToken, usr1, 5_000 ether, "Collat sent to liquidator");
        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, 4_000 ether, ILiquidator(address(0)));

        assertERC20Tracking();
        assertEq(market.positionDebt(usr1), 4_000 ether);
        assertEq(market.totalDebt(), 4_000 ether);
        assertEq(market.lastIR(), 0);

        uint256 tgUSDToRepay = 100;
        verifyLostERC20(tgUsd, usr1, tgUSDToRepay, "tgUSD burnt from sender");
        verifyReceiveERC20(collatToken, usr1, (tgUSDToRepay * market.collateralBalances(usr1)) / market.positionDebt(usr1), "Collat sent to liquidator");
        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, tgUSDToRepay, ILiquidator(address(0)));
        assertERC20Tracking();

        verifyLostERC20(tgUsd, usr1, market.positionDebt(usr1), "tgUSD burnt from sender");
        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "Collat sent to liquidator");
        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, market.positionDebt(usr1), ILiquidator(address(0)));
        assertERC20Tracking();

        vm.stopPrank();
    }
}

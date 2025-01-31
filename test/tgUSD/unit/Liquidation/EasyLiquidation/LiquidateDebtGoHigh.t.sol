// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../handler/Features/HProcessRewards.sol";

contract LiquidateDebtGoHigh is ConvexCurveContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    ICurveStableSwapNG public lp;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_FXUSD;
        lp = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1, market);
    }

    function test_liquidate_all_after_tgUSD_depegs() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether, true, address(0));

        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, address(0), 0, "");
        vm.stopPrank();

        // Dumps tgUSD for USDC => Depegs tgUSD
        hLpManipulator.dumpCrvPool(lp, 1, 0, 4_500 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, address(0), 0, "");

        assertLt(lp.last_price(0), 991 * 10 ** 15, "Last price dropped hard");

        skip(800);
        assertLt(oracles[tgUSD].latestAnswer(), 995 * 10 ** 15, "Price is goig down brutally after EMA is following");

        // Update IR on the market
        market.checkpointIR();

        assertGt(market.lastIR(), 40 ether, "IR should skyrocket as peg of tgUSD is low");

        // Go to the limit of the health ratio
        skip(70 days);
        // Liquidation doesn't pass, the HR is very close to 1 but still >
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, address(0), 0, "");

        // The position from this point liquidable
        skip(15 days);

        deal(address(tgUSD), usr1, market.positionDebt(usr1));

        assertLe(market.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(market.positionDebt(usr1), 4650 ether, "Debt is getting over the 93% of the collateral");

        verifyLostERC20(tgUSD, usr1, market.positionDebt(usr1), "tgUSD burnt from sender");
        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "tgUSD burnt from sender");
        // Liquidation passes after IR increased the user debt over the liquidation threshold
        market.liquidate(usr1, MAX_UINT, address(0), 0, "");
        assertERC20Tracking();

        assertEq(market.positionDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }
}

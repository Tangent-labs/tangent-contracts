// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../../handler/Features/HProcessRewards.sol";

contract LiquidateDebtGoHigh is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    HLPManipulator public hLpManipulator;
    ICurveStableSwapNG public lp;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        lp = lpDeploymentContext.USGLPs("USG-USDC");
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
        hLpManipulator = new HLPManipulator(usr1);
    }

    function test_liquidate_all_after_USG_depegs() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether, false);

        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: collatDeposited, minUsgOut: 0, maxUsgToBurn: 0, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        vm.stopPrank();

        // Dumps USG for USDC => Depegs USG
        hLpManipulator.dumpCrvPool(lp, 1, 0, 450_500 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: collatDeposited, minUsgOut: 0, maxUsgToBurn: 0, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );

        assertLt(lp.last_price(0), 991 * 10 ** 15, "Last price dropped hard");

        skip(800);
        assertLt(USGOracle.price(), 995 * 10 ** 15, "Price is goig down brutally after EMA is following");

        // Update IR on the market
        irCalculator.checkpointIR(address(market));

        assertEq(irCalculator.getIRCheckpoint(address(market)).ir, 4 ether, "IR should skyrocket and reach the max as peg of USG is low");

        // Go to the limit of the health ratio
        skip(8 days);
        // Liquidation doesn't pass, the HR is very close to 1 but still >
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: collatDeposited, minUsgOut: 0, maxUsgToBurn: MAX_UINT, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );

        // The position from this point liquidable
        skip(15 days);

        deal(address(usg), usr1, marketViewer.userDebt(market, usr1));

        assertLe(marketViewer.healthRatio(address(market), usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(marketViewer.userDebt(market, usr1), 4650 ether, "Debt is getting over the 93% of the collateral");

        verifyLostERC20(usg, usr1, marketViewer.userDebt(market, usr1), "USG burnt from sender");
        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "USG burnt from sender");
        // Liquidation passes after IR increased the user debt over the liquidation threshold
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: collatDeposited, minUsgOut: 0, maxUsgToBurn: MAX_UINT, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
        assertERC20Tracking();

        assertEq(marketViewer.userDebt(market, usr1), 0);
        assertEq(marketViewer.totalDebt(market), 0);

        vm.stopPrank();
    }

    function test_liquidate_fails_because_minAmountToLiquidate_slippage() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether, false);

        // Dumps USG for USDC => Depegs USG
        hLpManipulator.dumpCrvPool(lp, 1, 0, 450_500 ether);

        vm.startPrank(usr1);
        skip(800);

        // Update IR on the market
        irCalculator.checkpointIR(address(market));

        // Go to the limit of the health ratio
        skip(300 days);

        deal(address(usg), usr1, marketViewer.userDebt(market, usr1));
        // Liquidation doesn't pass, the HR is very close to 1 but still >
        vm.expectRevert(abi.encodeWithSelector(MarketCore.MinCollatToLiquidate.selector, collatDeposited));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: MAX_UINT,
                    minUsgOut: 0,
                    maxUsgToBurn: MAX_UINT,
                    minCollatAmountToLiquidate: collatDeposited + 1,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
    }

    function test_liquidate_fails_when_debtShares_are_zero() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether, false);

        // Dumps USG for USDC => Depegs USG
        hLpManipulator.dumpCrvPool(lp, 1, 0, 450_500 ether);

        vm.startPrank(usr1);
        skip(800);

        // Update IR on the market
        irCalculator.checkpointIR(address(market));

        // Go to the limit of the health ratio
        skip(300 days);

        deal(address(usg), usr1, marketViewer.userDebt(market, usr1));
        // Liquidation doesn't pass, the HR is very close to 1 but still >
        vm.expectRevert(abi.encodeWithSelector(DebtIR.ZeroDebtAmount.selector));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: 1, minUsgOut: 0, maxUsgToBurn: MAX_UINT, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
    }

    function test_liquidate_fails_when_collatValue_is_too_low() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether, false);

        // Dumps USG for USDC => Depegs USG
        hLpManipulator.dumpCrvPool(lp, 1, 0, 450_500 ether);

        vm.startPrank(usr1);
        skip(800);

        // Update IR on the market
        irCalculator.checkpointIR(address(market));

        // Go to the limit of the health ratio
        skip(16 days);

        deal(address(usg), usr1, marketViewer.userDebt(market, usr1));
        uint256 collatValue = (market.collatOracle().latestAnswer(true) * collatDeposited) / 1e18;

        vm.expectRevert(abi.encodeWithSelector(MarketCore.CollatValueToLiquidateTooLow.selector, collatValue));
        market.liquidate(
            LiquidateIn({
                account: usr1,
                postLiquidate: PostLiquidate({collatAmountToLiquidate: collatDeposited, minUsgOut: 0, maxUsgToBurn: MAX_UINT, minCollatAmountToLiquidate: 0, isReceiptOut: false}),
                minCollatValueToLiquidate: collatValue + 1
            }),
            ZapStruct({router: address(0), routerCall: ""})
        );
    }
}

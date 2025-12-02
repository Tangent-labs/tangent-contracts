// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateDirect is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;

        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hDeposit.depositAndBorrow(collatDeposited, initialDebt, false);
    }

    function test_selfLiquidate_all_position_with_USG_having_before() external {
        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        verifyBurnERC20(usg, initialDebt, "usg Burnt after a repay");
        verifyLostERC20(usg, usr1, initialDebt, "usg taken from usr1");

        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: collatDeposited, usgToRepay: MAX_UINT, maxUsgToBurn: MAX_UINT, minUsgOut: initialDebt, isReceiptOut: false}),
            ZapStruct({router: address(0), routerCall: ""})
        );

        assertERC20Tracking();

        assertEq(market.collateralBalances(usr1), 0);
        assertEq(market.totalCollateral(), 0);
        assertEq(marketViewer.userDebt(market, usr1), 0);
        assertEq(marketViewer.totalDebt(market), 0);

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_with_small_debt_shares_to_remove_zero() external {
        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        // Dump USG
        HLPManipulator lpManipulator = new HLPManipulator(owner);
        lpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 1, 0, 400_000 ether);

        // Adjust oracle price
        skip(1 hours);

        irCalculator.checkpointIR(address(market));

        skip(20 days);

        marketViewer.healthRatio(address(market), usr1);

        vm.expectRevert(abi.encodeWithSelector(DebtIR.ZeroDebtAmount.selector));
        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: 3, usgToRepay: 1, maxUsgToBurn: MAX_UINT, minUsgOut: initialDebt, isReceiptOut: false}),
            ZapStruct({router: address(0), routerCall: ""})
        );

        vm.stopPrank();
    }
}

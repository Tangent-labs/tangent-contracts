// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateReverts is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;

    ICurveStableSwapNG public lpUSG_USDC;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;

        lpUSG_USDC = lpDeploymentContext.USGLPs("usg-USDC");
        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);

        uint256 zero = 0;

        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToUSG = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams.push(unwrapLPToUSDC);
        swapParams.push(swapUsdcToUSG);

        hDeposit.depositAndBorrow(collatDeposited, initialDebt, false);

        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrClassicERC20.USDC));
        route.push(address(lpUSG_USDC));
        route.push(address(usg));
    }

    function test_selfLiquidate_liquidate_zero_collateral() external {
        vm.startPrank(usr1);
        uint256 amountToLiquidate = 1_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 4_250 ether, usr1));

        vm.expectRevert(abi.encodeWithSelector(Collateral.ZeroCollatAmount.selector));

        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: 0, usgToRepay: 1_000 ether, maxUsgToBurn: MAX_UINT, minUsgOut: 4250 ether, isReceiptOut: false}),
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routerCall})
        );

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_debt_left_lower_than_minDebt() external {
        vm.startPrank(usr1);

        uint256 amountToRepay = 3_000 ether;
        uint256 amountToLiquidate = 1_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(DebtIR.UserDebtTooLow.selector));
        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: amountToLiquidate, usgToRepay: amountToRepay, maxUsgToBurn: MAX_UINT, minUsgOut: 0, isReceiptOut: false}),
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routerCall})
        );

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_debt_left_too_high_compare_to_maxLTV() external {
        vm.startPrank(usr1);

        uint256 amountToLiquidate = 3_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(Collateral.OverMaxLTV.selector));
        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: amountToLiquidate, usgToRepay: 0, maxUsgToBurn: 0, minUsgOut: 0, isReceiptOut: false}),
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routerCall})
        );
        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_slippage_not_matching() external {
        vm.startPrank(usr1);

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatDeposited, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(ZappingProxy.MinAmountOutNotReached.selector));
        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: collatDeposited, usgToRepay: MAX_UINT, maxUsgToBurn: MAX_UINT, minUsgOut: 6_000 ether, isReceiptOut: false}),
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routerCall})
        );

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_burns_too_much_usg() external {
        vm.startPrank(usr1);

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatDeposited, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(MarketCore.MaxUSGToBurn.selector));
        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: collatDeposited, usgToRepay: MAX_UINT, maxUsgToBurn: 3_000 ether, minUsgOut: 6_000 ether, isReceiptOut: false}),
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routerCall})
        );

        vm.stopPrank();
    }
}

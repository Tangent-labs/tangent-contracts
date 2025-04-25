// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateReverts is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;

    ICurveStableSwapNG public lpTgUSD_USDC;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;

        lpTgUSD_USDC = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);

        uint256 zero = 0;

        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams.push(unwrapLPToUSDC);
        swapParams.push(swapUsdcToTgUSD);

        hDeposit.depositAndBorrow(collatDeposited, initialDebt, true, address(0));

        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrClassicERC20.USDC));
        route.push(address(lpTgUSD_USDC));
        route.push(address(tgUSD));
    }

    function test_selfLiquidate_liquidate_zero_collateral() external {
        vm.startPrank(usr1);
        uint256 amountToLiquidate = 1_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 4_250 ether, usr1));

        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.selfLiquidate(0, 1_000 ether, address(AddrRouter.ROUTER_CURVE), 4_250 ether, routerCall);

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_debt_left_lower_than_minDebt() external {
        vm.startPrank(usr1);

        uint256 amountToRepay = 3_000 ether;
        uint256 amountToLiquidate = 1_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooLow.selector));
        market.selfLiquidate(amountToLiquidate, amountToRepay, address(AddrRouter.ROUTER_CURVE), 0, routerCall);

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_debt_left_too_high_compare_to_maxLTV() external {
        vm.startPrank(usr1);

        uint256 amountToLiquidate = 3_000 ether;

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.selfLiquidate(amountToLiquidate, 0, address(AddrRouter.ROUTER_CURVE), 0, routerCall);

        vm.stopPrank();
    }

    function test_selfLiquidate_fails_because_slippage_not_matching() external {
        vm.startPrank(usr1);

        bytes memory routerCall = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatDeposited, 0, usr1));

        vm.expectRevert(abi.encodeWithSelector(LiquidatorProxy.MinAmountOutNotReached.selector));
        market.selfLiquidate(collatDeposited, MAX_UINT, address(AddrRouter.ROUTER_CURVE), 6_000 ether, routerCall);

        vm.stopPrank();
    }
}

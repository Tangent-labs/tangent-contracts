// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateCurveLP is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    ICurveStableSwapNG public lpTgUSD_USDC;
    ICurveStableSwapNG public lpTgUSD_wfrxUSD;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        lpTgUSD_USDC = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        lpTgUSD_wfrxUSD = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD");

        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1);

        uint256 zero = 0;

        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams.push(unwrapLPToUSDC);
        swapParams.push(swapUsdcToTgUSD);

        hDeposit.depositAndBorrow(collatDeposited, initialDebt, true);

        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrClassicERC20.USDC));
        route.push(address(lpTgUSD_USDC));
        route.push(address(tgUSD));
    }

    function test_selfLiquidate_all_position_curveLP() external {
        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        market.selfLiquidate(
            collatDeposited,
            MAX_UINT,
            address(AddrRouter.ROUTER_CURVE),
            4_250 ether,
            encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatToDump, 4_250 ether, usr1))
        );

        assertEq(market.collateralBalances(usr1), 0);
        assertEq(market.totalCollateral(), 0);
        assertEq(market.userDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }

    function test_selfLiquidate_partial_position_curveLP() external {
        vm.startPrank(usr1);

        uint256 amountToRepay = 1_000 ether;
        uint256 amountToLiquidate = 1_000 ether;

        uint256 surplus = tgUSD.balanceOf(usr1);
        market.selfLiquidate(
            amountToLiquidate,
            amountToRepay,
            address(AddrRouter.ROUTER_CURVE),
            0,
            encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1))
        );
        surplus = tgUSD.balanceOf(usr1) - surplus;

        assertGt(surplus, 10 ether);

        assertEq(market.collateralBalances(usr1), collatDeposited - amountToLiquidate);
        assertEq(market.totalCollateral(), collatDeposited - amountToLiquidate);
        assertEq(market.userDebt(usr1), initialDebt - amountToRepay);
        assertEq(market.totalDebt(), initialDebt - amountToRepay);

        vm.stopPrank();
    }
}

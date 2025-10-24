// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateCurveLP is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLPManipulator public hLpManipulator;
    ICurveStableSwapNG public lpUSG_USDC;
    ICurveStableSwapNG public lpUSG_wfrxUSD;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        lpUSG_USDC = lpDeploymentContext.USGLPs("USG-USDC");
        lpUSG_wfrxUSD = lpDeploymentContext.USGLPs("USG-wcrvUSD");

        market = deployConvexCurveLPMarket(collatToken, true);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLPManipulator(usr1);

        uint256 zero = 0;

        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToUSG = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams.push(unwrapLPToUSDC);
        swapParams.push(swapUsdcToUSG);

        hDeposit.depositAndBorrow(collatDeposited, initialDebt);

        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrCurveStableLP.USDC_crvUSD));
        route.push(address(AddrClassicERC20.USDC));
        route.push(address(lpUSG_USDC));
        route.push(address(usg));
    }

    function test_selfLiquidate_all_position_curveLP() external {
        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        market.selfLiquidate(
            collatDeposited,
            MAX_UINT,
            MAX_UINT,
            4_250 ether,
            ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatToDump, 4_250 ether, usr1))
            })
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

        uint256 surplus = usg.balanceOf(usr1);
        market.selfLiquidate(
            amountToLiquidate,
            amountToRepay,
            MAX_UINT,
            0,
            ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, amountToLiquidate, 0, usr1))
            })
        );
        surplus = usg.balanceOf(usr1) - surplus;

        assertGt(surplus, 10 ether);

        assertEq(market.collateralBalances(usr1), collatDeposited - amountToLiquidate);
        assertEq(market.totalCollateral(), collatDeposited - amountToLiquidate);
        assertEq(market.userDebt(usr1), initialDebt - amountToRepay);
        assertEq(market.totalDebt(), initialDebt - amountToRepay);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigratoorCurveLPToCurveLP is MarketDeploymentContext {
    IERC20Metadata public collatTokenFrom = AddrCurveStableLP.USDC_crvUSD;
    IERC20Metadata public collatTokenTo = AddrCurveStableLP.USDT_crvUSD;
    MarketExternalActions public marketFrom;
    MarketExternalActions public marketTo;

    uint256 constant collatIn = 100_000 ether;
    uint256 constant debtIn = 90_000 ether;

    uint256 constant collatToWithdraw = 45_000 ether;
    uint256 constant debtToRemove = 42_500 ether;
    uint256 constant debtToRepay = 5_000 ether;

    uint256[][] public swapParams;

    ZapMigrateStruct zapCall;

    function setUp() public {
        marketFrom = deployConvexCurveLPMarket(collatTokenFrom, false);
        marketTo = deployConvexCurveLPMarket(collatTokenTo, false);

        vm.startPrank(usr1);
        deal(address(collatTokenFrom), usr1, collatIn);
        collatTokenFrom.approve(address(marketFrom), MAX_UINT);
        marketFrom.depositAndBorrow(collatIn, 90_000 ether);

        swapParams.push(Array.memoryUint256([uint256(0), uint256(1), uint256(6), uint256(10), uint256(2)]));
        swapParams.push(Array.memoryUint256([uint256(1), uint256(0), uint256(4), uint256(1), uint256(2)]));
    }
    function test_full_repay_transfer_0_debt() external {
        vm.startPrank(usr1);

        // Create a second position on the target market
        deal(address(collatTokenTo), usr1, collatIn);
        collatTokenTo.approve(address(marketTo), MAX_UINT);
        marketTo.depositAndBorrow(collatIn, 90_000 ether);

        MigrateStruct memory migrateStruct = MigrateStruct({
            markets: Array.memoryAddress([address(marketFrom), address(marketTo)]),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: MAX_UINT,
            debtToRepay: MAX_UINT
        });

        zapCall = ZapMigrateStruct({
            zap: ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(
                    encoder.createCurveRouterStruct(
                        Array.memoryAddress([address(collatTokenFrom), address(collatTokenFrom), address(AddrClassicERC20.crvUSD), address(collatTokenTo), address(collatTokenTo)]),
                        swapParams,
                        collatToWithdraw,
                        0,
                        address(marketTo)
                    )
                )
            }),
            minCollatToOut: 0
        });

        migratoor.migrate(migrateStruct, zapCall);

        assertEq(marketFrom.collateralBalances(usr1), collatIn - collatToWithdraw);
        assertApproxEqRel(marketTo.collateralBalances(usr1), collatToWithdraw + collatIn, 1e16);

        // assertEq(marketFrom.userDebt(usr1), 0);
        // assertEq(marketTo.userDebt(usr1), debtIn);

        // assertEq(marketFrom.totalCollateral(), 0);
        // assertApproxEqRel(marketTo.totalCollateral(), collatIn, 1e16);

        // assertEq(marketFrom.totalDebt(), 0);
        // assertEq(marketTo.totalDebt(), debtIn);

        // assertEq(collatTokenFrom.balanceOf(address(marketFrom)), 0);
        // assertApproxEqRel(collatTokenTo.balanceOf(address(marketTo)), collatIn, 1e16);
    }

    function test_full_migrate_and_repay_0() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            markets: Array.memoryAddress([address(marketFrom), address(marketTo)]),
            collatToWithdraw: collatIn,
            debtToRemove: MAX_UINT,
            debtToRepay: 0
        });

        zapCall = ZapMigrateStruct({
            zap: ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(
                    encoder.createCurveRouterStruct(
                        Array.memoryAddress([address(collatTokenFrom), address(collatTokenFrom), address(AddrClassicERC20.crvUSD), address(collatTokenTo), address(collatTokenTo)]),
                        swapParams,
                        collatIn,
                        0,
                        address(marketTo)
                    )
                )
            }),
            minCollatToOut: 0
        });

        vm.startPrank(usr1);
        migratoor.migrate(migrateStruct, zapCall);

        assertEq(marketFrom.collateralBalances(usr1), 0);
        assertApproxEqRel(marketTo.collateralBalances(usr1), collatIn, 1e16);

        assertEq(marketFrom.userDebt(usr1), 0);
        assertEq(marketTo.userDebt(usr1), debtIn);

        assertEq(marketFrom.totalCollateral(), 0);
        assertApproxEqRel(marketTo.totalCollateral(), collatIn, 1e16);

        assertEq(marketFrom.totalDebt(), 0);
        assertEq(marketTo.totalDebt(), debtIn);

        assertEq(collatTokenFrom.balanceOf(address(marketFrom)), 0);
        assertApproxEqRel(collatTokenTo.balanceOf(address(marketTo)), collatIn, 1e16);
    }

    function test_partial_migrate() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            markets: Array.memoryAddress([address(marketFrom), address(marketTo)]),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        zapCall = ZapMigrateStruct({
            zap: ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(
                    encoder.createCurveRouterStruct(
                        Array.memoryAddress([address(collatTokenFrom), address(collatTokenFrom), address(AddrClassicERC20.crvUSD), address(collatTokenTo), address(collatTokenTo)]),
                        swapParams,
                        collatToWithdraw,
                        0,
                        address(marketTo)
                    )
                )
            }),
            minCollatToOut: 0
        });

        vm.startPrank(usr1);
        migratoor.migrate(migrateStruct, zapCall);

        assertEq(marketFrom.collateralBalances(usr1), collatIn - collatToWithdraw);
        assertApproxEqAbs(marketTo.collateralBalances(usr1), collatToWithdraw, 50 ether);

        assertEq(marketFrom.userDebt(usr1), debtIn - debtToRemove);
        assertEq(marketTo.userDebt(usr1), debtToRemove - debtToRepay);

        assertEq(marketFrom.totalCollateral(), collatIn - collatToWithdraw);
        assertApproxEqAbs(marketTo.totalCollateral(), collatToWithdraw, 50 ether);

        assertEq(marketFrom.totalDebt(), debtIn - debtToRemove);
        assertEq(marketTo.totalDebt(), debtToRemove - debtToRepay);

        assertEq(collatTokenFrom.balanceOf(address(marketFrom)), collatIn - collatToWithdraw);
        assertApproxEqAbs(collatTokenTo.balanceOf(address(marketTo)), collatToWithdraw, 50 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigratoorSameCollateral is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.USDC_crvUSD;
    ConvexCrvLPMarket public marketFrom;
    ConvexCrvLPMarket public marketTo;

    uint256 constant collatIn = 100_000 ether;
    uint256 constant debtInFrom = 70_000 ether;
    uint256 constant debtInTo = 90_000 ether;

    uint256 constant collatToWithdraw = 30_000 ether;
    uint256 constant debtToRemove = 35_000 ether;
    uint256 constant debtToRepay = 10_000 ether;

    function setUp() public {
        marketFrom = deployConvexCurveLPMarket(collatToken);
        marketTo = deployConvexCurveLPMarket(collatToken);

        vm.startPrank(usr1);
        deal(address(collatToken), usr1, 2 * collatIn);

        collatToken.approve(address(marketFrom), MAX_UINT);
        collatToken.approve(address(marketTo), MAX_UINT);

        marketFrom.depositAndBorrow(collatIn, debtInFrom, false);
        marketTo.depositAndBorrow(collatIn, debtInTo, false);
    }

    function test_exchange_USDC_crvUSD() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0});

        vm.startPrank(usr1);
        migratoor.migrate(migrateStruct, zapCall);

        assertEq(marketFrom.collateralBalances(address(usr1)), collatIn - collatToWithdraw);
        assertEq(marketTo.collateralBalances(address(usr1)), collatIn + collatToWithdraw);

        assertEq((marketFrom.cvxRewardToken()).balanceOf(address(marketFrom)), collatIn - collatToWithdraw);
        assertEq((marketTo.cvxRewardToken()).balanceOf(address(marketTo)), collatIn + collatToWithdraw);

        assertEq(marketFrom.totalCollateral(), collatIn - collatToWithdraw);
        assertEq(marketTo.totalCollateral(), collatIn + collatToWithdraw);

        assertEq(marketViewer.userDebt(marketFrom, usr1), debtInFrom - debtToRemove);
        assertEq(marketViewer.userDebt(marketTo, usr1), debtInTo + (debtToRemove - debtToRepay));

        assertEq(marketViewer.totalDebt(marketFrom), debtInFrom - debtToRemove);
        assertEq(marketViewer.totalDebt(marketTo), debtInTo + (debtToRemove - debtToRepay));
    }
}

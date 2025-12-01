// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigrateConvexToStakeDao is MarketDeploymentContext {
    IERC20Metadata public collat = AddrCurveStableLP.USDC_crvUSD;
    ConvexCrvLPMarket public marketConvex;
    StakeDaoVaultV2Market public marketStakeDao;

    uint256 constant collatIn = 100_000 ether;
    uint256 constant debtIn = 50_000 ether;

    uint256 constant collatToWithdraw = 10_000 ether;
    uint256 constant debtToRemove = 8_000 ether;
    uint256 constant debtToRepay = 1_000 ether;

    uint256[][] public swapParams;

    function setUp() public {
        marketConvex = deployConvexCurveLPMarket(collat);
        marketStakeDao = deployStakeDaoVaultV2Market(collat);

        vm.startPrank(usr1);
        deal(address(collat), usr1, collatIn);
        collat.approve(address(marketConvex), MAX_UINT);
        marketConvex.depositAndBorrow(collatIn, debtIn, false);
    }

    function test_migrate_same_LP_Convex_to_StakeDao() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketConvex),
            marketTo: address(marketStakeDao),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });
        verifyLostERC20(marketConvex.cvxRewardToken(), address(marketConvex), collatToWithdraw, "Convex market sent collateral in the migration");
        verifyReceiveERC20(marketStakeDao.vaultToken(), address(marketStakeDao), collatToWithdraw, "StakeDao market receives collateral in the migration");

        vm.startPrank(usr1);
        migratoor.migrate(migrateStruct, ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0}));

        assertERC20Tracking();

        // Collateral check
        assertEq(marketConvex.collateralBalances(usr1), collatIn - collatToWithdraw);
        assertEq(marketConvex.totalCollateral(), marketConvex.collateralBalances(usr1));

        assertEq(marketStakeDao.collateralBalances(usr1), collatToWithdraw);
        assertEq(marketStakeDao.totalCollateral(), marketStakeDao.collateralBalances(usr1));

        // Debt check

        assertEq(marketViewer.userDebt(marketConvex, usr1), debtIn - debtToRemove, "User debt is equal to the inital debt minus what needs to be removed");
        assertEq(marketViewer.totalDebt(marketConvex), marketViewer.userDebt(marketConvex, usr1));

        assertEq(marketViewer.userDebt(marketStakeDao, usr1), debtToRemove - debtToRepay, "User debt is equal to the inital debt minus what needs to be removed");
        assertEq(marketViewer.totalDebt(marketStakeDao), marketViewer.userDebt(marketStakeDao, usr1));
    }
}

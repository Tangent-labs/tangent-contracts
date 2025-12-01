// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigratoorReverts is MarketDeploymentContext {
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

    function test_migrate_marketFrom_not_a_market_fails() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(usr1),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0});

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(Migratoor.NotAMarket.selector));
        migratoor.migrate(migrateStruct, zapCall);
    }

    function test_migrate_marketTo_not_a_market_fails() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(usr1),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0});

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(Migratoor.NotAMarket.selector));
        migratoor.migrate(migrateStruct, zapCall);
    }

    function test_migrate_identical_markets_fails() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketTo),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0});

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(Migratoor.IdenticalMarkets.selector));
        migratoor.migrate(migrateStruct, zapCall);
    }

    function test_migrate_with_debtToRepay_bigger_than_debt_on_marketFrom() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRemove + 1
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({zap: ZapStruct({router: address(0), routerCall: ""}), minCollatToOut: 0});

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.DebtToRepayTooBig.selector));
        migratoor.migrate(migrateStruct, zapCall);
    }

    function test_call_migrateFrom_not_from_migratoor_fails() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotAMigratoor.selector));
        marketFrom.migrateFrom(usr1, 0, 0, 0, address(0));
    }

    function test_call_migrateTo_not_from_migratoor_fails() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotAMigratoor.selector));
        marketFrom.migrateTo(usr1, 0, 0);
    }
}

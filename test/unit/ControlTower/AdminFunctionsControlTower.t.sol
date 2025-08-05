// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract AdminFunctionsControlTower is MarketDeploymentContext {
    function test_toggleMarket_success_as_owner() external {
        vm.startPrank(owner);
        controlTower.toggleMarket(usr2);
        assertEq(controlTower.isMarket(usr2), true);

        controlTower.toggleMarket(usr2);
        assertEq(controlTower.isMarket(usr2), false);
    }

    function test_toggleMarket_success_as_marketCreator() external {
        vm.prank(owner);
        controlTower.toggleMarketCreator(usr2);

        vm.startPrank(usr2);
        controlTower.toggleMarket(usr1);
        assertEq(controlTower.isMarket(usr1), true);

        controlTower.toggleMarket(usr1);
        assertEq(controlTower.isMarket(usr1), false);
    }

    function test_toggleMarketCreator_success() external {
        vm.startPrank(owner);
        controlTower.toggleMarketCreator(usr2);
        assertEq(controlTower.isMarketCreator(usr2), true);

        controlTower.toggleMarketCreator(usr2);
        assertEq(controlTower.isMarketCreator(usr2), false);
    }

    function test_togglePegKeeper_success() external {
        vm.startPrank(owner);
        controlTower.togglePegKeeper(usr2);
        assertEq(controlTower.isPegKeeper(usr2), true);

        controlTower.togglePegKeeper(usr2);
        assertEq(controlTower.isPegKeeper(usr2), false);
    }

    function test_toggleIRCalculator_success() external {
        vm.startPrank(owner);
        controlTower.toggleIRCalculator(usr2);
        assertEq(controlTower.isIRCalculator(usr2), true);

        controlTower.toggleIRCalculator(usr2);
        assertEq(controlTower.isIRCalculator(usr2), false);
    }

    function test_togglePositionMigrator_success() external {
        vm.startPrank(owner);
        controlTower.togglePositionMigrator(usr2);
        assertEq(controlTower.isPositionMigrator(usr2), true);

        controlTower.togglePositionMigrator(usr2);
        assertEq(controlTower.isPositionMigrator(usr2), false);
    }

    function test_togglePauser_success() external {
        vm.startPrank(owner);
        controlTower.togglePauser(usr2);
        assertEq(controlTower.isPauser(usr2), true);

        controlTower.togglePauser(usr2);
        assertEq(controlTower.isPauser(usr2), false);
    }
}

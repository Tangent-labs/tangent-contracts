// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract AdminFunctionsControlTower is MarketDeploymentContext {
    function test_setTreasury_success() external {
        vm.startPrank(owner);
        controlTower.setFeeTreasury(usr2);
        assertEq(controlTower.feeTreasury(), usr2);

        controlTower.setFeeTreasury(usr1);
        assertEq(controlTower.feeTreasury(), usr1);

        controlTower.setFeeTreasury(usr3);
        assertEq(controlTower.feeTreasury(), usr3);
    }

    function test_toggleMarketCreator_success() external {
        vm.startPrank(owner);
        controlTower.setIsMarketCreator(usr2, true);
        assertEq(controlTower.isMarketCreator(usr2), true);

        controlTower.setIsMarketCreator(usr2, false);
        assertEq(controlTower.isMarketCreator(usr2), false);
    }

    function test_togglePositionMigrator_success() external {
        vm.startPrank(owner);
        controlTower.setIsPositionMigrator(usr2, true);
        assertEq(controlTower.isPositionMigrator(usr2), true);

        controlTower.setIsPositionMigrator(usr2, false);
        assertEq(controlTower.isPositionMigrator(usr2), false);
    }

    function test_togglePauser_success() external {
        vm.startPrank(owner);
        controlTower.setIsPauser(usr2, true);
        assertEq(controlTower.isPauser(usr2), true);

        controlTower.setIsPauser(usr2, false);
        assertEq(controlTower.isPauser(usr2), false);
    }
}

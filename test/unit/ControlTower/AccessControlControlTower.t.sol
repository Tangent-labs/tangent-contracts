// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {MarketDeploymentContext, ControlTower, LightOwnable} from "../../contexts/MarketDeploymentContext.sol";
contract AccessControlControlTower is MarketDeploymentContext {
    function test_setFeeTreasury_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.setFeeTreasury(usr2);
    }

    function test_setIsMarketCreator_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.setIsMarketCreator(usr2, true);
    }

    function test_setIsPositionMigrator_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.setIsPositionMigrator(usr2, true);
    }

    function test_setIsPauser_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.setIsPauser(usr2, true);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {MarketDeploymentContext, ControlTower, LightOwnable} from "../../contexts/MarketDeploymentContext.sol";
contract AccessControlControlTower is MarketDeploymentContext {
    function test_toggleMarket_fails_as_not_owner_or_market_creator() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(ControlTower.CallerNotOwnerOrMarketCreator.selector, usr1));
        controlTower.toggleMarket(usr2);
    }

    function test_toggleMarketCreator_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.toggleMarketCreator(usr2);
    }

    function test_togglePegKeeper_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.togglePegKeeper(usr2);
    }

    function test_toggleIRCalculator_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        controlTower.toggleIRCalculator(usr2);
    }
}

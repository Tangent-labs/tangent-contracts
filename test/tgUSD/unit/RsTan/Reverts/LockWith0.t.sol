// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Curve/HLpManipulator.sol";

contract LockWith0 is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTan), 2 * amount);
        rsTan.createLock(amount, true);
        rsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_fails_to_create_lock_with_0_TAN() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1 ether);
        tan.approve(address(rsTan), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(RsTan.ZeroAmount.selector));
        rsTan.createLock(0, true);
    }
}

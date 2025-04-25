// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract TogglePermaLock is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTanService), 2 * amount);
        rsTanService.createLock(amount, true, address(0));
        rsTanService.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_togglePermaLock_from_false_to_true() external {
        vm.startPrank(usr1);
        uint256 oldEndLockTimeExpected = rsTanService.nextEndLockTime();
        (uint48 oldEndLockTime, ) = rsTanService.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);

        rsTanService.togglePermaLock(2);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTanService.locks(2);
        assertEq(rsTanService.MAX_UINT48(), newEndLockTime, "Permalocked");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_from_true_to_false() external {
        vm.startPrank(usr1);
        uint256 nextEndLockTime = rsTanService.nextEndLockTime();
        (uint48 oldEndLockTime, ) = rsTanService.locks(1);
        assertEq(oldEndLockTime, rsTanService.MAX_UINT48());

        rsTanService.togglePermaLock(1);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTanService.locks(1);

        assertEq(nextEndLockTime, newEndLockTime, "Not Permalocked anymore");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_to_true_fails_bcs_lock_over() external {
        vm.startPrank(usr1);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(RsTanService.LockExpired.selector));
        rsTanService.togglePermaLock(2);
    }

    function test_togglePermaLock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTanService.NotTokenOwner.selector));
        rsTanService.togglePermaLock(2);
    }
}

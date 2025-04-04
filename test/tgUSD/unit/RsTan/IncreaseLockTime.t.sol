// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract IncreaseLockTime is ConvexCurveContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTanService), 2 * amount);
        rsTanService.createLock(amount, true, address(0));
        rsTanService.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_increase_time() external {
        uint256 oldEndLockTimeExpected = rsTanService.nextEndLockTime();

        (uint48 oldEndLockTime, uint208 amountBefore) = rsTanService.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);
        assertEq(amountBefore, amount);
        skip(1 weeks);

        vm.startPrank(usr1);
        rsTanService.increaseLockTime(2);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTanService.locks(2);

        assertEq(oldEndLockTime + 1 weeks, newEndLockTime, "After time is increased");
        assertEq(amountAfter, amount);
    }

    function test_increase_time_position_not_owned() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.NotTokenOwner.selector));
        rsTanService.increaseLockTime(1);
    }

    function test_increase_on_expired_position() external {
        skip(13 weeks);
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.LockExpired.selector));
        rsTanService.increaseLockTime(2);
    }

    function test_increase_time_on_perma_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.CantIncreaseTimePermaLock.selector));
        rsTanService.increaseLockTime(1);
    }

    function test_increase_time_on_already_max_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.AlreadyMaxLock.selector));
        rsTanService.increaseLockTime(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract IncreaseLockTime is ConvexCurveContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTan), 2 * amount);
        rsTan.createLock(amount, true, address(0));
        rsTan.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_increase_time() external {
        uint256 oldEndLockTimeExpected = rsTan.nextEndLockTime();

        (uint48 oldEndLockTime, uint208 amountBefore) = rsTan.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);
        assertEq(amountBefore, amount);
        skip(1 weeks);

        vm.startPrank(usr1);
        rsTan.increaseLockTime(2);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTan.locks(2);

        assertEq(oldEndLockTime + 1 weeks, newEndLockTime, "After time is increased");
        assertEq(amountAfter, amount);

        assertEq(rsTan.amountDecrFromTotal(oldEndLockTime), 0);
        assertEq(rsTan.amountDecrFromTotal(newEndLockTime), 1 ether);
    }

    function test_increase_time_position_not_owned() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.increaseLockTime(1);
    }

    function test_increase_on_expired_position() external {
        skip(13 weeks);
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTan.LockExpired.selector));
        rsTan.increaseLockTime(2);
    }

    function test_increase_time_on_perma_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTan.CantIncreaseTimePermaLock.selector));
        rsTan.increaseLockTime(1);
    }

    function test_increase_time_on_already_max_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTan.AlreadyMaxLock.selector));
        rsTan.increaseLockTime(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract TogglePermaLock is ConvexCurveContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTan), 2 * amount);
        rsTan.createLock(amount, true, address(0));
        rsTan.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_togglePermaLock_from_false_to_true() external {
        vm.startPrank(usr1);
        uint256 oldEndLockTimeExpected = rsTan.nextEndLockTime();
        (uint48 oldEndLockTime, uint208 amountBefore) = rsTan.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);
        assertEq(rsTan.amountDecrFromTotal(oldEndLockTime), amount, "Only one is for now not permalocked");

        rsTan.togglePermaLock(2);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTan.locks(2);
        assertEq(rsTan.MAX_UINT48(), newEndLockTime, "Permalocked");
        assertEq(amountAfter, amount);
        assertEq(rsTan.amountDecrFromTotal(oldEndLockTime), 0, "There is nothing more to remove at the oldEndLock time because both positions are permalocked");
    }

    function test_togglePermaLock_from_true_to_false() external {
        vm.startPrank(usr1);
        uint256 nextEndLockTime = rsTan.nextEndLockTime();
        (uint48 oldEndLockTime, uint208 amountBefore) = rsTan.locks(1);
        assertEq(oldEndLockTime, rsTan.MAX_UINT48());
        assertEq(rsTan.amountDecrFromTotal(nextEndLockTime), amount, "Only one positions expires");

        rsTan.togglePermaLock(1);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTan.locks(1);

        assertEq(nextEndLockTime, newEndLockTime, "Not Permalocked anymore");
        assertEq(amountAfter, amount);

        assertEq(rsTan.amountDecrFromTotal(nextEndLockTime), 2 * amount, "Both positions are ending at the same moment");
    }

    function test_togglePermaLock_to_true_fails_bcs_lock_over() external {
        vm.startPrank(usr1);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(RsTan.LockExpired.selector));
        rsTan.togglePermaLock(2);
    }

    function test_togglePermaLock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.togglePermaLock(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract IncreaseLockTime is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(vsTan), 2 * amount);
        vsTan.createLock(amount, true);
        vsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_increase_time() external {
        uint256 oldEndLockTimeExpected = vsTan.nextEndLockTime();

        (uint48 oldEndLockTime, uint208 amountBefore) = vsTan.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);
        assertEq(amountBefore, amount);
        skip(1 weeks);

        vm.startPrank(usr1);
        vsTan.increaseLockTime(2);

        (uint48 newEndLockTime, uint208 amountAfter) = vsTan.locks(2);

        assertEq(oldEndLockTime + 1 weeks, newEndLockTime, "After time is increased");
        assertEq(amountAfter, amount);
    }

    function test_increase_time_position_not_owned() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(VsTan.NotTokenOwner.selector));
        vsTan.increaseLockTime(1);
    }

    function test_increase_on_expired_position() external {
        skip(13 weeks);
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(VsTan.LockExpired.selector));
        vsTan.increaseLockTime(2);
    }

    function test_increase_time_on_perma_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(VsTan.CantIncreaseTimePermaLock.selector));
        vsTan.increaseLockTime(1);
    }

    function test_increase_time_on_already_max_lock() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(VsTan.AlreadyMaxLock.selector));
        vsTan.increaseLockTime(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract CreateLock is MarketDeploymentContext {
    function test_create_lock() external {
        // Lock perma with user 1 and amount1
        uint208 amount1 = 10_000 ether;
        uint208 amount2 = 20_000 ether;

        vm.startPrank(usr1);
        deal(address(tan), usr1, amount1);

        verifyReceiveERC20(tan, address(vsTan), amount1, "Rs TAN receive TAN");
        verifyLostERC20(tan, usr1, amount1, "User 1 lost TAN");

        tan.approve(address(vsTan), amount1);
        vsTan.createLock(amount1, true);

        assertERC20Tracking();
        assertEq(vsTan.balanceOf(usr1), 1);
        assertEq(vsTan.tokenOfOwnerByIndex(usr1, 0), 1);
        assertEq(vsTan.totalSupplyVsTan(), amount1);
        (uint256 endLockTime, uint256 lockAmount) = vsTan.locks(1);
        assertEq(endLockTime, vsTan.MAX_UINT48());
        assertEq(lockAmount, amount1);

        vm.stopPrank();

        // Go EXACTLY on the next week ( multiple of 1 week in second )
        uint256 nextWeekTimestamp = ((block.timestamp + 1 weeks) / 1 weeks) * 1 weeks;
        skip(nextWeekTimestamp - block.timestamp);

        // Lock not not perma with user 2 and amount2

        vm.startPrank(usr2);
        deal(address(tan), usr2, amount2);

        verifyReceiveERC20(tan, address(vsTan), amount2, "Rs TAN receive TAN");
        verifyLostERC20(tan, usr2, amount2, "User 2 lost TAN");

        uint256 expectedEndTime = ((block.timestamp + vsTan.LOCK_DURATION()) / 1 weeks) * 1 weeks;

        tan.approve(address(vsTan), amount2);
        vsTan.createLock(amount2, false);

        assertERC20Tracking();
        assertEq(vsTan.balanceOf(usr2), 1);
        assertEq(vsTan.tokenOfOwnerByIndex(usr2, 0), 2);
        assertEq(vsTan.totalSupplyVsTan(), amount1 + amount2);
        (endLockTime, lockAmount) = vsTan.locks(2);
        assertEq(endLockTime, expectedEndTime);
        assertEq(lockAmount, amount2);

        vm.stopPrank();

        // Lock not not perma with user 1 and send lock to user2

        vm.startPrank(usr1);
        deal(address(tan), usr1, amount2);

        verifyReceiveERC20(tan, address(vsTan), amount2, "Rs TAN receive TAN");
        verifyLostERC20(tan, usr1, amount2, "User 1 lost TAN");

        expectedEndTime = ((block.timestamp + vsTan.LOCK_DURATION()) / 1 weeks) * 1 weeks;

        tan.approve(address(vsTan), amount2);
        vsTan.createLock(amount2, false);

        assertERC20Tracking();
        assertEq(vsTan.balanceOf(usr2), 1);
        assertEq(vsTan.tokenOfOwnerByIndex(usr2, 0), 2);
        assertEq(vsTan.tokenOfOwnerByIndex(usr1, 1), 3);
        assertEq(vsTan.totalSupplyVsTan(), amount1 + 2 * amount2);
        (endLockTime, lockAmount) = vsTan.locks(3);
        assertEq(endLockTime, expectedEndTime);
        assertEq(lockAmount, amount2);
    }

    function test_fails_to_create_lock_with_0_TAN() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1 ether);
        tan.approve(address(vsTan), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.MinLockAmountNotReached.selector));
        vsTan.createLock(0, true);
    }
}

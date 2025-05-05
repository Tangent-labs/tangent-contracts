// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract CreateLock is MarketDeploymentContext {
    function test_create_lock() external {
        // Lock perma with user 1 and amount1
        uint208 amount1 = 10_000 ether;
        uint208 amount2 = 20_000 ether;

        vm.startPrank(usr1);
        deal(address(tan), usr1, amount1);

        verifyReceiveERC20(tan, address(rsTan), amount1, "Rs Tan receive TAN");
        verifyLostERC20(tan, usr1, amount1, "User 1 lost TAN");

        tan.approve(address(rsTan), amount1);
        rsTan.createLock(amount1, true);

        assertERC20Tracking();
        assertEq(rsTan.balanceOf(usr1), 1);
        assertEq(rsTan.tokenOfOwnerByIndex(usr1, 0), 1);
        assertEq(rsTan.totalSupplyRsTan(), amount1);
        (uint256 endLockTime, uint256 lockAmount) = rsTan.locks(1);
        assertEq(endLockTime, rsTan.MAX_UINT48());
        assertEq(lockAmount, amount1);

        vm.stopPrank();

        // Go EXACTLY on the next week ( multiple of 1 week in second )
        uint256 nextWeekTimestamp = ((block.timestamp + 1 weeks) / 1 weeks) * 1 weeks;
        skip(nextWeekTimestamp - block.timestamp);

        // Lock not not perma with user 2 and amount2

        vm.startPrank(usr2);
        deal(address(tan), usr2, amount2);

        verifyReceiveERC20(tan, address(rsTan), amount2, "Rs Tan receive TAN");
        verifyLostERC20(tan, usr2, amount2, "User 2 lost TAN");

        uint256 expectedEndTime = ((block.timestamp + rsTan.LOCK_DURATION()) / 1 weeks) * 1 weeks;

        tan.approve(address(rsTan), amount2);
        rsTan.createLock(amount2, false);

        assertERC20Tracking();
        assertEq(rsTan.balanceOf(usr2), 1);
        assertEq(rsTan.tokenOfOwnerByIndex(usr2, 0), 2);
        assertEq(rsTan.totalSupplyRsTan(), amount1 + amount2);
        (endLockTime, lockAmount) = rsTan.locks(2);
        assertEq(endLockTime, expectedEndTime);
        assertEq(lockAmount, amount2);

        vm.stopPrank();

        // Lock not not perma with user 1 and send lock to user2

        vm.startPrank(usr1);
        deal(address(tan), usr1, amount2);

        verifyReceiveERC20(tan, address(rsTan), amount2, "Rs Tan receive TAN");
        verifyLostERC20(tan, usr1, amount2, "User 1 lost TAN");

        expectedEndTime = ((block.timestamp + rsTan.LOCK_DURATION()) / 1 weeks) * 1 weeks;

        tan.approve(address(rsTan), amount2);
        rsTan.createLock(amount2, false);

        assertERC20Tracking();
        assertEq(rsTan.balanceOf(usr2), 1);
        assertEq(rsTan.tokenOfOwnerByIndex(usr2, 0), 2);
        assertEq(rsTan.tokenOfOwnerByIndex(usr1, 1), 3);
        assertEq(rsTan.totalSupplyRsTan(), amount1 + 2 * amount2);
        (endLockTime, lockAmount) = rsTan.locks(3);
        assertEq(endLockTime, expectedEndTime);
        assertEq(lockAmount, amount2);
    }
}

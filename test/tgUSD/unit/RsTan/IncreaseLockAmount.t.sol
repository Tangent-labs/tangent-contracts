// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract IncreaseLockAmount is ConvexCurveContext {
    uint208 amount0 = 10_000 ether;
    uint208 amount1 = 5_000 ether;

    uint256 fullAmount = amount0 + amount1;
    function test_increase_lock_amount_perma_locked() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(rsTan), fullAmount);

        rsTan.createLock(amount0, true, address(0));

        (uint256 endLockTime0, ) = rsTan.locks(1);

        verifyReceiveERC20(tan, address(rsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);
        rsTan.increaseLockAmount(1, amount1, address(0));

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTan.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, rsTan.MAX_UINT48());

        assertEq(amountLocked1, fullAmount);
        assertEq(rsTan.totalSupplyRsTan(), fullAmount);
    }

    function test_increase_lock_amount_not_perma_locked_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(rsTan), fullAmount);

        rsTan.createLock(amount0, false, address(0));
        uint48 endLockTime = rsTan.nextEndLockTime();
        (uint256 endLockTime0, ) = rsTan.locks(1);

        verifyReceiveERC20(tan, address(rsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);

        rsTan.increaseLockAmount(1, amount1, address(0));

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTan.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, endLockTime);

        assertEq(amountLocked1, fullAmount);
        assertEq(rsTan.totalSupplyRsTan(), fullAmount);
    }

    function test_increase_lock_amount_not_perma_locked_not_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 100_000 ether);
        tan.approve(address(rsTan), MAX_UINT);

        rsTan.createLock(amount0, false, address(0));
        uint48 endLockTime0 = rsTan.nextEndLockTime();

        skip(6 weeks);

        rsTan.createLock(amount0, false, address(0));

        skip(6 weeks);

        verifyReceiveERC20(tan, address(rsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);

        rsTan.increaseLockAmount(1, amount1, address(0));

        assertERC20Tracking();

        uint48 endLockTime1Expected = rsTan.nextEndLockTime();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTan.locks(1);

        assertEq(endLockTime1Expected, endLockTime1);
        assertEq(endLockTime1, endLockTime0 + 12 weeks);

        assertEq(amountLocked1, fullAmount, "Amount locked on the token is right");

        assertEq(rsTan.totalSupplyRsTan(), fullAmount + amount0, "Total Supply increased properly");

        skip(7 weeks);

        assertEq(rsTan.totalSupplyRsTan(), fullAmount);

        verifyReceiveERC20(tan, usr1, amount0);
        verifyLostERC20(tan, address(rsTan), amount0);
        rsTan.unlock(2);
        assertERC20Tracking();

        assertEq(rsTan.totalSupplyRsTan(), fullAmount);
        skip(6 weeks);
        assertEq(rsTan.totalSupplyRsTan(), 0, "Total supply is now 0");
    }

    function test_fails_to_increase_lock_on_token_not_owned() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1 ether);
        tan.approve(address(rsTan), 1 ether);
        rsTan.createLock(1 ether, true, address(0));
        vm.stopPrank();

        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.increaseLockAmount(1, 1, address(0));
    }
}

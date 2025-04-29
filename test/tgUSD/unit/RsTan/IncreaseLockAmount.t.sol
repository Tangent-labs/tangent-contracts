// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract IncreaseLockAmount is MarketDeploymentContext {
    uint208 amount0 = 10_000 ether;
    uint208 amount1 = 5_000 ether;

    uint256 fullAmount = amount0 + amount1;
    function test_increase_lock_amount_perma_locked() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(rsTanService), fullAmount);

        rsTanService.createLock(amount0, true);

        (uint256 endLockTime0, ) = rsTanService.locks(1);

        verifyReceiveERC20(tan, address(rsTanService), amount1);
        verifyLostERC20(tan, usr1, amount1);
        rsTanService.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTanService.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, rsTanService.MAX_UINT48());

        assertEq(amountLocked1, fullAmount);
        assertEq(rsTanService.totalSupplyRsTan(), fullAmount);
    }

    function test_increase_lock_amount_not_perma_locked_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(rsTanService), fullAmount);

        rsTanService.createLock(amount0, false);
        uint48 endLockTime = rsTanService.nextEndLockTime();
        (uint256 endLockTime0, ) = rsTanService.locks(1);

        verifyReceiveERC20(tan, address(rsTanService), amount1);
        verifyLostERC20(tan, usr1, amount1);

        rsTanService.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTanService.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, endLockTime);

        assertEq(amountLocked1, fullAmount, "Amount locked is equal to what has been locked");
        assertEq(rsTanService.totalSupplyRsTan(), fullAmount, "Total supply is equal to the amount of the first position as it's the only one");
    }

    function test_increase_lock_amount_not_perma_locked_not_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 100_000 ether);
        tan.approve(address(rsTanService), MAX_UINT);

        rsTanService.createLock(amount0, false);
        uint48 endLockTime0 = rsTanService.nextEndLockTime();

        skip(6 weeks);

        rsTanService.createLock(amount0, false);

        skip(6 weeks);

        verifyReceiveERC20(tan, address(rsTanService), amount1);
        verifyLostERC20(tan, usr1, amount1);

        rsTanService.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        uint48 endLockTime1Expected = rsTanService.nextEndLockTime();

        (uint256 endLockTime1, uint256 amountLocked1) = rsTanService.locks(1);

        assertEq(endLockTime1Expected, endLockTime1);
        assertEq(endLockTime1, endLockTime0 + 12 weeks);

        assertEq(amountLocked1, fullAmount, "Amount locked on the token is right");
        assertEq(rsTanService.totalSupplyRsTan(), fullAmount + amount0, "Total Supply increased properly");

        skip(7 weeks);

        assertEq(rsTanService.totalSupplyRsTan(), fullAmount + amount0, "Position still locked because not kicked yet");

        verifyReceiveERC20(tan, usr1, amount0);
        verifyLostERC20(tan, address(rsTanService), amount0);
        rsTanService.unlock(2);
        assertERC20Tracking();

        assertEq(rsTanService.totalSupplyRsTan(), fullAmount, "Equals to what is on position 1");
        skip(6 weeks);
        assertEq(rsTanService.totalSupplyRsTan(), fullAmount, "Total supply is still the same ");
    }

    function test_fails_to_increase_lock_on_token_not_owned() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1 ether);
        tan.approve(address(rsTanService), 1 ether);
        rsTanService.createLock(1 ether, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.NotTokenOwner.selector));
        rsTanService.increaseLockAmount(1, 1);
    }
}

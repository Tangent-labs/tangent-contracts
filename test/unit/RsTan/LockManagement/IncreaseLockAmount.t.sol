// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract IncreaseLockAmount is MarketDeploymentContext {
    uint208 amount0 = 10_000 ether;
    uint208 amount1 = 5_000 ether;

    uint256 fullAmount = amount0 + amount1;
    function test_increase_lock_amount_perma_locked() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(vsTan), fullAmount);

        vsTan.createLock(amount0, true);

        (uint256 endLockTime0, ) = vsTan.locks(1);

        verifyReceiveERC20(tan, address(vsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);
        vsTan.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = vsTan.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, vsTan.MAX_UINT48());

        assertEq(amountLocked1, fullAmount);
        assertEq(vsTan.totalSupplyVsTan(), fullAmount);
    }

    function test_increase_lock_amount_not_perma_locked_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, fullAmount);
        tan.approve(address(vsTan), fullAmount);

        vsTan.createLock(amount0, false);
        uint48 endLockTime = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);
        (uint256 endLockTime0, ) = vsTan.locks(1);

        verifyReceiveERC20(tan, address(vsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);

        vsTan.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        (uint256 endLockTime1, uint256 amountLocked1) = vsTan.locks(1);

        assertEq(endLockTime0, endLockTime1);
        assertEq(endLockTime0, endLockTime);

        assertEq(amountLocked1, fullAmount, "Amount locked is equal to what has been locked");
        assertEq(vsTan.totalSupplyVsTan(), fullAmount, "Total supply is equal to the amount of the first position as it's the only one");
    }

    function test_increase_lock_amount_not_perma_locked_not_same_week() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 100_000 ether);
        tan.approve(address(vsTan), MAX_UINT);

        vsTan.createLock(amount0, false);
        uint48 endLockTime0 = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);

        skip(6 weeks);

        vsTan.createLock(amount0, false);

        skip(6 weeks);

        verifyReceiveERC20(tan, address(vsTan), amount1);
        verifyLostERC20(tan, usr1, amount1);

        vsTan.increaseLockAmount(1, amount1);

        assertERC20Tracking();

        uint48 endLockTime1Expected = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);

        (uint256 endLockTime1, uint256 amountLocked1) = vsTan.locks(1);

        assertEq(endLockTime1Expected, endLockTime1);
        assertEq(endLockTime1, endLockTime0 + 12 weeks);

        assertEq(amountLocked1, fullAmount, "Amount locked on the token is right");
        assertEq(vsTan.totalSupplyVsTan(), fullAmount + amount0, "Total Supply increased properly");

        skip(7 weeks);

        assertEq(vsTan.totalSupplyVsTan(), fullAmount + amount0, "Position still locked because not kicked yet");

        verifyReceiveERC20(tan, usr1, amount0);
        verifyLostERC20(tan, address(vsTan), amount0);
        vsTan.unlock(2, false);
        assertERC20Tracking();

        assertEq(vsTan.totalSupplyVsTan(), fullAmount, "Equals to what is on position 1");
        skip(6 weeks);
        assertEq(vsTan.totalSupplyVsTan(), fullAmount, "Total supply is still the same ");
    }

    function test_fails_to_increase_lock_on_token_not_owned() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1000 ether);
        tan.approve(address(vsTan), 1000 ether);
        vsTan.createLock(1000 ether, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.increaseLockAmount(1, 1);
    }

    function test_fails_to_increaseLockAmount_zeroAmount() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 1000 ether);
        tan.approve(address(vsTan), 1000 ether);
        vsTan.createLock(1000 ether, true);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.ZeroAmount.selector));
        vsTan.increaseLockAmount(1, 0);
    }

    function test_fails_to_increaseLockAmount_on_expired_position() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, amount0);
        tan.approve(address(vsTan), amount0);
        vsTan.createLock(amount0, false);

        skip(vsTan.LOCK_DURATION());
        vm.expectRevert(abi.encodeWithSelector(VsTAN.LockExpired.selector));
        vsTan.increaseLockAmount(1, 1);
    }
}

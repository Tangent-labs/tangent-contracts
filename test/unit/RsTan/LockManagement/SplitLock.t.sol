// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract SplitLock is MarketDeploymentContext {
    uint208 amount0 = 20_000 ether;
    uint208 amount1 = 10_000 ether;
    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount0);
        tan.approve(address(vsTan), 2 * amount0);
        vsTan.createLock(amount0, true);
        vsTan.createLock(amount1, false);
        vm.stopPrank();
    }

    function test_split_perma_lock() external {
        vm.startPrank(usr1);
        uint208 removedAmount = amount0 / 3;

        vsTan.split(1, removedAmount);

        (uint48 endLock1, uint208 amount1After) = vsTan.locks(1);
        (uint48 endLock3, uint208 amount3) = vsTan.locks(3);
        assertEq(endLock1, endLock3);
        assertEq(endLock1, vsTan.MAX_UINT48());

        assertEq(amount1After, amount0 - removedAmount);
        assertEq(amount3, removedAmount);

        assertEq(vsTan.ownerOf(1), usr1);
        assertEq(vsTan.ownerOf(3), usr1);
        assertEq(vsTan.balanceOf(usr1), 3);
        assertEq(vsTan.totalSupply(), 3);
    }

    function test_split_not_perma_lock() external {
        vm.startPrank(usr1);
        uint208 removedAmount = amount0 / 4;

        skip(1 weeks);

        vsTan.split(2, removedAmount);

        (uint48 endLock1, uint208 amount1After) = vsTan.locks(2);
        (uint48 endLock3, uint208 amount3) = vsTan.locks(3);
        assertEq(endLock1, endLock3);

        assertEq(amount1After, amount1 - removedAmount);
        assertEq(amount3, removedAmount);

        assertEq(vsTan.ownerOf(1), usr1);
        assertEq(vsTan.ownerOf(3), usr1);
        assertEq(vsTan.balanceOf(usr1), 3);
        assertEq(vsTan.totalSupply(), 3);
    }

    function test_split_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.split(2, 100);
    }

    function test_split_fails_bcs_split_more_than_balance() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.BiggerThanInitialPosition.selector));
        vsTan.split(2, amount1);
    }

    function test_split_fails_bcs_split_and_remove_zero() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.MinLockAmountNotReached.selector));
        vsTan.split(2, 9_999 ether);
    }

    function test_split_fails_bcs_old_token_is_too_small() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.MinLockAmountNotReached.selector));
        vsTan.split(2, 0);
    }

    function test_split_fails_bcs_position_expired() external {
        vm.startPrank(usr1);

        skip(vsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(VsTAN.LockExpired.selector));
        vsTan.split(2, 1_000 ether);
    }
}

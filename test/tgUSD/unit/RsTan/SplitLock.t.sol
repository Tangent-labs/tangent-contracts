// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract SplitLock is ConvexCurveContext {
    uint208 amount0 = 20_000 ether;
    uint208 amount1 = 10_000 ether;
    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount0);
        tan.approve(address(rsTan), 2 * amount0);
        rsTan.createLock(amount0, true, address(0));
        rsTan.createLock(amount1, false, address(0));
        vm.stopPrank();
    }

    function test_split_perma_lock() external {
        vm.startPrank(usr1);
        uint208 removedAmount = amount0 / 3;

        rsTan.split(1, removedAmount);

        (uint48 endLock1, uint208 amount1After) = rsTan.locks(1);
        (uint48 endLock3, uint208 amount3) = rsTan.locks(3);
        assertEq(endLock1, endLock3);
        assertEq(endLock1, rsTan.MAX_UINT48());

        assertEq(amount1After, amount0 - removedAmount);
        assertEq(amount3, removedAmount);

        assertEq(rsTan.ownerOf(1), usr1);
        assertEq(rsTan.ownerOf(3), usr1);
        assertEq(rsTan.balanceOf(usr1), 3);
        assertEq(rsTan.totalSupply(), 3);
    }

    function test_split_not_perma_lock() external {
        vm.startPrank(usr1);
        uint208 removedAmount = amount0 / 4;

        skip(1 weeks);

        rsTan.split(2, removedAmount);

        (uint48 endLock1, uint208 amount1After) = rsTan.locks(2);
        (uint48 endLock3, uint208 amount3) = rsTan.locks(3);
        assertEq(endLock1, endLock3);

        assertEq(amount1After, amount1 - removedAmount);
        assertEq(amount3, removedAmount);

        assertEq(rsTan.ownerOf(1), usr1);
        assertEq(rsTan.ownerOf(3), usr1);
        assertEq(rsTan.balanceOf(usr1), 3);
        assertEq(rsTan.totalSupply(), 3);
    }

    function test_split_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.split(2, 100);
    }

    function test_split_fails_bcs_split_more_than_balance() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTan.BiggerThanInitialPosition.selector));
        rsTan.split(2, amount1);
    }

    function test_split_fails_bcs_split_and_remove_zero() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTan.ZeroAmount.selector));
        rsTan.split(2, 0);
    }
}

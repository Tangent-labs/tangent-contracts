// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract MergeLock is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 3 * amount);
        tan.approve(address(rsTan), 3 * amount);
        // 1 is permalocked
        rsTan.createLock(amount, true);
        // 2 is not permalocked
        rsTan.createLock(amount, false);
        skip(1 weeks);
        // 3 is not permalocked and created later than 2
        rsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_merge_tokenA_endlock_bigger_than_tokenB() external {
        vm.startPrank(usr1);
        (uint48 endLockBefore, uint208 amount3Before) = rsTan.locks(3);
        rsTan.merge(3, 2, false);
        (uint48 endLockAfter, uint208 amountMerged) = rsTan.locks(3);

        assertEq(amountMerged, 2 * amount);
        assertEq(endLockBefore, endLockAfter);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTan.ownerOf(2);
    }

    function test_merge_tokenB_endlock_bigger_than_tokenA() external {
        vm.startPrank(usr1);
        (uint48 endLock2, uint208 amount2Before) = rsTan.locks(2);
        rsTan.merge(2, 3, false);
        (uint48 endLockAfter, uint208 amountMerged) = rsTan.locks(2);

        assertEq(amountMerged, 2 * amount);
        assertEq(endLock2 + 1 weeks, endLockAfter);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 3));
        rsTan.ownerOf(3);
    }

    function test_merge_fails_bcs_position_A_expired() external {
        vm.startPrank(usr1);

        skip(rsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(RsTan.LockExpired.selector));
        rsTan.merge(1, 3, false);
    }

    function test_merge_fails_bcs_position_B_expired() external {
        vm.startPrank(usr1);

        skip(rsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(RsTan.LockExpired.selector));
        rsTan.merge(3, 1, false);
    }
}

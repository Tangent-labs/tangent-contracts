// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MergeLock is ConvexCurveContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 3 * amount);
        tan.approve(address(rsTan), 3 * amount);
        // 1 is permalocked
        rsTan.createLock(amount, true, address(0));
        // 2 is not permalocked
        rsTan.createLock(amount, false, address(0));
        skip(1 weeks);
        // 3 is not permalocked and created later than 2
        rsTan.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_merge_tokenA_endlock_bigger_than_tokenB() external {
        vm.startPrank(usr1);
        (uint48 endLockBefore, uint208 amount3Before) = rsTan.locks(3);
        rsTan.merge(3, 2);
        (uint48 endLockAfter, uint208 amountMerged) = rsTan.locks(3);

        assertEq(amountMerged, 2 * amount);
        assertEq(endLockBefore, endLockAfter);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTan.ownerOf(2);
    }

    function test_merge_tokenB_endlock_bigger_than_tokenA() external {
        vm.startPrank(usr1);
        (uint48 endLock2, uint208 amount2Before) = rsTan.locks(2);
        rsTan.merge(2, 3);
        (uint48 endLockAfter, uint208 amountMerged) = rsTan.locks(2);

        assertEq(amountMerged, 2 * amount);
        assertEq(endLock2 + 1 weeks, endLockAfter);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 3));
        rsTan.ownerOf(3);
    }
}

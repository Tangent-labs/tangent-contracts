// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Unlock is ConvexCurveContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTan), 2 * amount);
        // 1 is permalocked
        rsTan.createLock(amount, true, address(0));
        // 2 is not permalocked
        rsTan.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_burn_expired_position() external {
        vm.startPrank(usr1);
        skip(12 weeks);
        assertEq(rsTan.totalSupply(), 2);
        assertEq(rsTan.totalSupplyRsTan(), 2 * amount);
        assertEq(rsTan.totalSupplyRsTan(), 2 * amount);
        skip(1 weeks);

        verifyLostERC20(tan, address(rsTan), amount, "Tan are unlocked and sent back to user from the rsTan");
        verifyReceiveERC20(tan, usr1, amount, "Tan received by user");

        assertEq(rsTan.balanceOf(usr1), 2);
        assertEq(rsTan.ownerOf(1), usr1);
        assertEq(rsTan.ownerOf(2), usr1);

        rsTan.unlock(2);

        assertERC20Tracking();

        assertEq(rsTan.totalSupplyRsTan(), amount);
        assertEq(rsTan.totalSupply(), 1);
        assertEq(rsTan.balanceOf(usr1), 1);
        assertEq(rsTan.ownerOf(1), usr1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTan.ownerOf(2);
    }

    function test_unlock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.unlock(2);
    }

    function test_unlock_fails_bcs_lock_not_finished() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTan.LockNotOver.selector));
        rsTan.unlock(2);
    }
}

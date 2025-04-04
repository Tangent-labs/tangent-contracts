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
        tan.approve(address(rsTanService), 2 * amount);
        // 1 is permalocked
        rsTanService.createLock(amount, true, address(0));
        // 2 is not permalocked
        rsTanService.createLock(amount, false, address(0));
        vm.stopPrank();
    }

    function test_burn_expired_position() external {
        vm.startPrank(usr1);
        skip(12 weeks);
        assertEq(rsTanERC721.totalSupply(), 2);
        assertEq(rsTanService.totalSupplyRsTan(), 2 * amount);
        assertEq(rsTanService.totalSupplyRsTan(), 2 * amount);
        skip(1 weeks);

        verifyLostERC20(tan, address(rsTanService), amount, "Tan are unlocked and sent back to user from the rsTanService");
        verifyReceiveERC20(tan, usr1, amount, "Tan received by user");

        assertEq(rsTanERC721.balanceOf(usr1), 2);
        assertEq(rsTanERC721.ownerOf(1), usr1);
        assertEq(rsTanERC721.ownerOf(2), usr1);

        rsTanService.unlock(2);

        assertERC20Tracking();

        assertEq(rsTanService.totalSupplyRsTan(), amount);
        assertEq(rsTanERC721.totalSupply(), 1);
        assertEq(rsTanERC721.balanceOf(usr1), 1);
        assertEq(rsTanERC721.ownerOf(1), usr1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTanERC721.ownerOf(2);
    }

    function test_unlock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(RsTanService.NotTokenOwner.selector));
        rsTanService.unlock(2);
    }

    function test_unlock_fails_bcs_lock_not_finished() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTanService.LockNotOver.selector));
        rsTanService.unlock(2);
    }
}

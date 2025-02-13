// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract RageQuit is ConvexCurveContext {
    uint208 amount = 900_000 ether;

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

    function test_rageQuit_permalock() external {
        vm.startPrank(usr1);

        skip(4 weeks + 3 days);

        uint256 nextLockTime = rsTan.nextEndLockTime();

        uint256 delta = nextLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTan.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTan), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTan.balanceOf(usr1), 2);
        assertEq(rsTan.ownerOf(1), usr1);

        rsTan.rageQuit(1);

        assertERC20Tracking();

        assertEq(rsTan.totalSupplyRsTan(), amount);
        assertEq(rsTan.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1));
        rsTan.ownerOf(1);
    }

    function test_rageQuit_not_permalocked_instant_after_lock() external {
        vm.startPrank(usr1);

        (uint256 endLockTime, ) = rsTan.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTan.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTan), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTan.balanceOf(usr1), 2);
        assertEq(rsTan.ownerOf(1), usr1);

        rsTan.rageQuit(2);

        assertERC20Tracking();

        assertEq(rsTan.totalSupplyRsTan(), amount);
        assertEq(rsTan.amountDecrFromTotal(endLockTime), 0);
        assertEq(rsTan.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTan.ownerOf(2);
    }

    function test_rageQuit_not_permalocked_and_wait_after_lock() external {
        vm.startPrank(usr1);

        skip(12 weeks);

        (uint256 endLockTime, ) = rsTan.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTan.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTan), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTan.balanceOf(usr1), 2);
        assertEq(rsTan.ownerOf(1), usr1);

        rsTan.rageQuit(2);

        assertERC20Tracking();

        assertEq(rsTan.totalSupplyRsTan(), amount);
        assertEq(rsTan.amountDecrFromTotal(endLockTime), 0);

        rsTan.rageQuit(1);

        assertEq(rsTan.totalSupplyRsTan(), 0);
        assertEq(rsTan.totalSupply(), 0);
        assertEq(tan.balanceOf(address(rsTan)), 0);

        for (uint256 index; index < 16; index++) {
            skip(1 weeks);
            rsTan.checkpoint();
        }
    }

    function test_rageQuit_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.rageQuit(2);
    }
}

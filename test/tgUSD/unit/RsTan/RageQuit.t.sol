// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract RageQuit is MarketDeploymentContext {
    uint208 amount = 900_000 ether;

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

    function test_rageQuit_permalock() external {
        vm.startPrank(usr1);

        skip(4 weeks + 3 days);

        uint256 nextLockTime = rsTanService.nextEndLockTime();

        uint256 delta = nextLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTanService.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTanService), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTanERC721.balanceOf(usr1), 2);
        assertEq(rsTanERC721.ownerOf(1), usr1);

        rsTanService.rageQuit(1);

        assertERC20Tracking();

        assertEq(rsTanService.totalSupplyRsTan(), amount);
        assertEq(rsTanERC721.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1));
        rsTanERC721.ownerOf(1);
    }

    function test_rageQuit_not_permalocked_instant_after_lock() external {
        vm.startPrank(usr1);

        (uint256 endLockTime, ) = rsTanService.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTanService.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTanService), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTanERC721.balanceOf(usr1), 2);
        assertEq(rsTanERC721.ownerOf(1), usr1);

        rsTanService.rageQuit(2);

        assertERC20Tracking();

        assertEq(rsTanService.totalSupplyRsTan(), amount);
        assertEq(rsTanERC721.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        rsTanERC721.ownerOf(2);
    }

    function test_rageQuit_not_permalocked_and_wait_after_lock() external {
        vm.startPrank(usr1);

        skip(12 weeks);

        (uint256 endLockTime, ) = rsTanService.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / rsTanService.LOCK_DURATION();

        verifyLostERC20(tan, address(rsTanService), amount, "All Tan of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(rsTanERC721.balanceOf(usr1), 2);
        assertEq(rsTanERC721.ownerOf(1), usr1);

        rsTanService.rageQuit(2);

        assertERC20Tracking();

        assertEq(rsTanService.totalSupplyRsTan(), amount);

        rsTanService.rageQuit(1);

        assertEq(rsTanService.totalSupplyRsTan(), 0);
        assertEq(rsTanERC721.totalSupply(), 0);
        assertEq(tan.balanceOf(address(rsTanService)), 0);

        for (uint256 index; index < 16; index++) {
            skip(1 weeks);
        }
    }

    function test_rageQuit_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTanService.NotTokenOwner.selector));
        rsTanService.rageQuit(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract RageQuit is MarketDeploymentContext {
    uint208 amount = 900_000 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(vsTan), 2 * amount);
        // 1 is permalocked
        vsTan.createLock(amount, true);
        // 2 is not permalocked
        vsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_rageQuit_permalock() external {
        vm.startPrank(usr1);

        skip(4 weeks + 3 days);

        uint256 nextLockTime = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);

        uint256 delta = nextLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / vsTan.LOCK_DURATION();

        console.log(amount, penalty);

        verifyLostERC20(tan, address(vsTan), amount, "All TAN of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(vsTan.balanceOf(usr1), 2);
        assertEq(vsTan.ownerOf(1), usr1);

        vsTan.rageQuit(1, false);

        assertERC20Tracking();

        assertEq(vsTan.totalSupplyVsTan(), amount);
        assertEq(vsTan.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1));
        vsTan.ownerOf(1);
    }

    function test_rageQuit_not_permalocked_instant_after_lock() external {
        vm.startPrank(usr1);

        (uint256 endLockTime, ) = vsTan.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / vsTan.LOCK_DURATION();

        assertNotEq(penalty, 0);

        verifyLostERC20(tan, address(vsTan), amount, "All TAN of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(vsTan.balanceOf(usr1), 2);
        assertEq(vsTan.ownerOf(1), usr1);

        vsTan.rageQuit(2, false);

        assertERC20Tracking();

        assertEq(vsTan.totalSupplyVsTan(), amount);
        assertEq(vsTan.totalSupply(), 1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        vsTan.ownerOf(2);
    }

    function test_rageQuit_not_permalocked_and_wait_after_lock() external {
        vm.startPrank(usr1);

        skip(12 weeks);

        (uint256 endLockTime, ) = vsTan.locks(2);

        uint256 delta = endLockTime - block.timestamp;
        uint256 penalty = (delta * amount) / vsTan.LOCK_DURATION();

        verifyLostERC20(tan, address(vsTan), amount, "All TAN of the positions are removed from the lock");
        verifyReceiveERC20(tan, feeTreasury, penalty, "Penalty received by FeeTreasury");
        verifyReceiveERC20(tan, usr1, amount - penalty, "The rest is claimed by the user");

        assertEq(vsTan.balanceOf(usr1), 2);
        assertEq(vsTan.ownerOf(1), usr1);

        vsTan.rageQuit(2, false);

        assertERC20Tracking();

        assertEq(vsTan.totalSupplyVsTan(), amount);

        vsTan.rageQuit(1, false);

        assertEq(vsTan.totalSupplyVsTan(), 0);
        assertEq(vsTan.totalSupply(), 0);
        assertEq(tan.balanceOf(address(vsTan)), 0);

        for (uint256 index; index < 16; index++) {
            skip(1 weeks);
        }
    }

    function test_rageQuit_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.rageQuit(2, false);
    }

    function test_rageQuit_fails_bcs_positionExpired() external {
        vm.startPrank(usr1);

        skip(vsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(VsTAN.LockExpired.selector));
        vsTan.rageQuit(2, false);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract Unlock is MarketDeploymentContext {
    uint208 amount = 1 ether;

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

    function test_burn_expired_position() external {
        vm.startPrank(usr1);
        skip(12 weeks);
        assertEq(vsTan.totalSupply(), 2);
        assertEq(vsTan.totalSupplyVsTan(), 2 * amount);
        assertEq(vsTan.totalSupplyVsTan(), 2 * amount);
        skip(1 weeks);

        verifyLostERC20(tan, address(vsTan), amount, "TAN are unlocked and sent back to user from the vsTan");
        verifyReceiveERC20(tan, usr1, amount, "TAN received by user");

        assertEq(vsTan.balanceOf(usr1), 2);
        assertEq(vsTan.ownerOf(1), usr1);
        assertEq(vsTan.ownerOf(2), usr1);

        vsTan.unlock(2, false);

        assertERC20Tracking();

        assertEq(vsTan.totalSupplyVsTan(), amount);
        assertEq(vsTan.totalSupply(), 1);
        assertEq(vsTan.balanceOf(usr1), 1);
        assertEq(vsTan.ownerOf(1), usr1);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 2));
        vsTan.ownerOf(2);
    }

    function test_unlock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.unlock(2, false);
    }

    function test_unlock_fails_bcs_lock_not_finished() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.LockNotOver.selector));
        vsTan.unlock(2, false);
    }
}

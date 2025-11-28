// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract TogglePermaLock is MarketDeploymentContext {
    uint208 amount = 10_000 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(vsTan), 2 * amount);
        vsTan.createLock(amount, true);
        vsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_togglePermaLock_from_false_to_true() external {
        vm.startPrank(usr1);
        uint256 oldEndLockTimeExpected = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);

        (uint48 oldEndLockTime, ) = vsTan.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);

        vsTan.togglePermaLock(2);

        (uint48 newEndLockTime, uint208 amountAfter) = vsTan.locks(2);
        assertEq(vsTan.MAX_UINT48(), newEndLockTime, "Permalocked");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_from_true_to_false() external {
        vm.startPrank(usr1);
        uint256 nextEndLockTime = uint48(((block.timestamp + 13 weeks) / 7 days) * 7 days);

        (uint48 oldEndLockTime, ) = vsTan.locks(1);
        assertEq(oldEndLockTime, vsTan.MAX_UINT48());

        vsTan.togglePermaLock(1);

        (uint48 newEndLockTime, uint208 amountAfter) = vsTan.locks(1);

        assertEq(nextEndLockTime, newEndLockTime, "Not Permalocked anymore");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_to_true_fails_bcs_lock_over() external {
        vm.startPrank(usr1);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.LockExpired.selector));
        vsTan.togglePermaLock(2);
    }

    function test_togglePermaLock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.togglePermaLock(2);
    }
}

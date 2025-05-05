// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract TogglePermaLock is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTan), 2 * amount);
        rsTan.createLock(amount, true);
        rsTan.createLock(amount, false);
        vm.stopPrank();
    }

    function test_togglePermaLock_from_false_to_true() external {
        vm.startPrank(usr1);
        uint256 oldEndLockTimeExpected = rsTan.nextEndLockTime();
        (uint48 oldEndLockTime, ) = rsTan.locks(2);
        assertEq(oldEndLockTimeExpected, oldEndLockTime);

        rsTan.togglePermaLock(2);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTan.locks(2);
        assertEq(rsTan.MAX_UINT48(), newEndLockTime, "Permalocked");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_from_true_to_false() external {
        vm.startPrank(usr1);
        uint256 nextEndLockTime = rsTan.nextEndLockTime();
        (uint48 oldEndLockTime, ) = rsTan.locks(1);
        assertEq(oldEndLockTime, rsTan.MAX_UINT48());

        rsTan.togglePermaLock(1);

        (uint48 newEndLockTime, uint208 amountAfter) = rsTan.locks(1);

        assertEq(nextEndLockTime, newEndLockTime, "Not Permalocked anymore");
        assertEq(amountAfter, amount);
    }

    function test_togglePermaLock_to_true_fails_bcs_lock_over() external {
        vm.startPrank(usr1);
        skip(13 weeks);

        vm.expectRevert(abi.encodeWithSelector(RsTan.LockExpired.selector));
        rsTan.togglePermaLock(2);
    }

    function test_togglePermaLock_fails_bcs_token_not_owned() external {
        vm.startPrank(usr2);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.togglePermaLock(2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ExpiredLockEarns is MarketDeploymentContext {
    uint208 amountToLock = 10_000 ether;

    function _lock(address usr) internal {
        vm.startPrank(usr);
        deal(address(tan), usr, amountToLock);
        tan.approve(address(vsTan), amountToLock);
        vsTan.createLock(amountToLock, false);
        vm.stopPrank();
    }

    function _reward(uint256 amount) internal {
        vm.startPrank(owner);
        usg.approve(address(vsTan), MAX_UINT);
        deal(address(usg), owner, amount);
        TokenAmount[] memory t = new TokenAmount[](1);
        t[0] = TokenAmount({token: usg, amount: amount});
        vsTan.processRewards(t);
        vm.stopPrank();
    }

    // usr1's lock expired a year ago, still earns exactly what usr2's live lock earns, and can exit penalty-free anytime
    function test_expired_lock_earns_like_live_lock() external {
        _lock(usr1); // id 1
        skip(vsTan.LOCK_DURATION() + 52 weeks);
        _lock(usr2); // id 2, freshly locked
        assertLt(vsTan.getLock(1).endLockTime, block.timestamp, "usr1 expired");

        _reward(1_000 ether);
        skip(1 weeks);

        uint256 r1 = vsTan.claimableRewards(1)[0].amount;
        uint256 r2 = vsTan.claimableRewards(2)[0].amount;
        assertApproxEqRel(r1, r2, 1e12, "expired lock earns same as live lock");

        vm.prank(usr1);
        vsTan.unlock(1, false);
        assertEq(tan.balanceOf(usr1), amountToLock, "no penalty");
        assertApproxEqRel(usg.balanceOf(usr1), 500 ether, 1e12, "half the week's rewards");
    }
}

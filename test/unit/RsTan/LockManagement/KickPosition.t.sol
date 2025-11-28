// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract KickPosition is MarketDeploymentContext {
    uint208 amountToLock = 10_000 ether;
    uint256 rewardAmount = 1_000 ether;

    function setUp() external {
        // Create a Lock
        vm.startPrank(usr1);
        deal(address(tan), usr1, 3 * amountToLock);
        tan.approve(address(vsTan), 3 * amountToLock);
        vsTan.createLock(amountToLock, false);
        vm.stopPrank();

        skip(1);

        // Process the rewards
        vm.startPrank(owner);
        usg.approve(address(vsTan), MAX_UINT);
        deal(address(usg), address(owner), rewardAmount);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: rewardAmount});
        vsTan.processRewards(tokenAmounts);
        vm.stopPrank();
    }

    function test_kick_expired_position() external {
        (uint128 delay, uint128 percentage) = vsTan.kick();

        skip(vsTan.LOCK_DURATION() + delay);

        Reward memory lastReward = vsTan.getRewardData(usg);

        uint256 kickIncentivization = (percentage * amountToLock) / 100_000;
        // TAN fluxes
        verifyReceiveERC20(tan, usr1, amountToLock - kickIncentivization, "Locker received his tan back, minus the kick penality");
        verifyReceiveERC20(tan, usr2, kickIncentivization, "Kicker received the penality");
        verifyLostERC20(tan, address(vsTan), amountToLock, "VsTAN sends TAN to Locker and Kicker");

        // usg fluxes
        verifyReceiveDeltaRelERC20(usg, usr1, rewardAmount, 1e14, "Claims the rewards in usg for the positionOwner");
        verifyLostDeltaRelERC20(usg, address(vsTan), rewardAmount, 1e14, "VsTAN looses the usg rewards");

        vm.startPrank(usr2);
        vsTan.kickPosition(1, usr2);

        assertERC20Tracking();

        // Verify rewards are updated
        assertGt(vsTan.getRewardData(usg).lastUpdateTime, lastReward.lastUpdateTime, "Checkpoints the rewards");
        assertEq(vsTan.rewards(1, usg), 0, "Nothing to claim as it's already done in the kick");

        Lock memory kickedLock = vsTan.getLock(1);
        assertEq(kickedLock.endLockTime, 0, "Lock Deleted endLockTime");
        assertEq(kickedLock.amount, 0, "Lock Deleted amount");

        assertEq(0, vsTan.balanceOf(usr1), "Usr1 doesn't have the NFT anymore");
        assertEq(0, vsTan.totalSupply(), "NFT have been burnt reduces the totalSupply");
    }

    function test_fails_kick_non_expired() external {
        skip(vsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(VsTAN.KickDelayIsNotPassed.selector));
        vsTan.kickPosition(1, usr2);
    }
}

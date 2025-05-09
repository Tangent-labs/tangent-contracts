// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract KickPosition is MarketDeploymentContext {
    uint208 amountToLock = 1 ether;
    uint256 rewardAmount = 1_000 ether;

    function setUp() external {
        // Create a Lock
        vm.startPrank(usr1);
        deal(address(tan), usr1, 3 * amountToLock);
        tan.approve(address(rsTan), 3 * amountToLock);
        rsTan.createLock(amountToLock, false);
        vm.stopPrank();

        skip(1);

        // Process the rewards
        vm.startPrank(owner);
        tgUSD.approve(address(rsTan), MAX_UINT);
        deal(address(tgUSD), address(owner), rewardAmount);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: rewardAmount});
        rsTan.processRewards(tokenAmounts);
        vm.stopPrank();
    }

    function test_kick_expired_position() external {
        (uint128 delay, uint128 percentage) = rsTan.kick();

        skip(rsTan.LOCK_DURATION() + delay);

        Reward memory lastReward = rsTan.getRewardData(tgUSD);

        uint256 kickIncentivization = (percentage * amountToLock) / 100_000;
        // TAN fluxes
        verifyReceiveERC20(tan, usr1, amountToLock - kickIncentivization, "Locker received his tan back, minus the kick penality");
        verifyReceiveERC20(tan, usr2, kickIncentivization, "Kicker received the penality");
        verifyLostERC20(tan, address(rsTan), amountToLock, "RsTan sends TAN to Locker and Kicker");

        // tgUSD fluxes
        verifyReceiveDeltaRelERC20(tgUSD, usr1, rewardAmount, 1e14, "Claims the rewards in tgUSD for the positionOwner");
        verifyLostDeltaRelERC20(tgUSD, address(rsTan), rewardAmount, 1e14, "RsTan looses the tgUSD rewards");

        vm.startPrank(usr2);
        rsTan.kickPosition(1, usr2);

        assertERC20Tracking();

        // Verify rewards are updated
        assertGt(rsTan.getRewardData(tgUSD).lastUpdateTime, lastReward.lastUpdateTime, "Checkpoints the rewards");
        assertEq(rsTan.rewards(1, tgUSD), 0, "Nothing to claim as it's already done in the kick");

        Lock memory kickedLock = rsTan.getLock(1);
        assertEq(kickedLock.endLockTime, 0, "Lock Deleted endLockTime");
        assertEq(kickedLock.amount, 0, "Lock Deleted amount");

        assertEq(0, rsTan.balanceOf(usr1), "Usr1 doesn't have the NFT anymore");
        assertEq(0, rsTan.totalSupply(), "NFT have been burnt reduces the totalSupply");
    }

    function test_fails_kick_non_expired() external {
        skip(rsTan.LOCK_DURATION());

        vm.expectRevert(abi.encodeWithSelector(RsTan.KickDelayIsNotPassed.selector));
        rsTan.kickPosition(1, usr2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract RewardsLock is ConvexCurveContext {
    function test_rewards_lock() external {
        // Lock perma with user 1 and amount1
        uint208 amount1 = 10_000 ether;
        uint208 amount2 = 20_000 ether;

        // Create a lock with usr1
        vm.startPrank(usr1);
        deal(address(tan), address(usr1), amount1);
        tan.approve(address(rsTan), MAX_UINT);
        rsTan.createLock(amount1, true, address(0));

        uint256 ts = block.timestamp;
        uint256 rateExpected = uint256(1_000 ether) / uint256(1 weeks);
        uint256 timeToSkip = 3.5 days;

        vm.stopPrank();

        // Process the rewards
        vm.startPrank(owner);
        tgUSD.approve(address(rsTan), MAX_UINT);
        deal(address(tgUSD), address(owner), 1_000 ether);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: 1_000 ether});
        rsTan.processRewards(tokenAmounts);
        vm.stopPrank();

        (uint128 lastUpdateTime, uint128 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored) = rsTan.rewardData(tgUSD);
        assertEq(lastUpdateTime, block.timestamp, "Last update time has changed because we created a lock");
        assertEq(periodFinish, ts + 1 weeks, "Period finish is the same ts");
        assertEq(rewardRate, uint256(1_000 ether) / uint256(1 weeks));
        assertEq(rewardPerTokenStored, 0);
        assertEq(rsTan.userRewardPerTokenPaid(1, tgUSD), 0);
        assertEq(rsTan.rewards(1, tgUSD), 0);

        // Pass some time & create the second lock with usr2
        vm.startPrank(usr2);
        skip(timeToSkip);
        deal(address(tan), address(usr2), amount2);
        tan.approve(address(rsTan), MAX_UINT);
        rsTan.createLock(amount2, false, address(0));

        (lastUpdateTime, periodFinish, rewardRate, rewardPerTokenStored) = rsTan.rewardData(tgUSD);
        assertEq(lastUpdateTime, block.timestamp, "A");
        assertEq(periodFinish, block.timestamp + timeToSkip, "B");
        assertEq(rewardRate, rateExpected, "Rate per token is incorrect");
        assertEq(rewardPerTokenStored, (timeToSkip * rateExpected * 1e18) / amount1, "Reward per token stored incorrect");
        // assertEq(rsTan.userRewardPerTokenPaid(1, tgUSD), 0, "e");
        // assertEq(rsTan.rewards(1, tgUSD), 0, "f");
        vm.stopPrank();

        skip(5 days);

        // rsTan.processRewards();
        vm.prank(usr1);
        rsTan.claimRewards(1);

        vm.prank(usr2);
        rsTan.claimRewards(2);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTan.NothingToClaim.selector));
        rsTan.claimRewards(1);
    }
}

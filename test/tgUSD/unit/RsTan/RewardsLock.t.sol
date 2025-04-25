// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract RewardsLock is MarketDeploymentContext {
    function test_lock_claimSimple() external {
        // Lock perma with user 1 and amount1
        uint208 amount1 = 10_000 ether;
        uint208 amount2 = 20_000 ether;

        uint256 rewardAmount = 1_000 ether;

        // Create a lock with usr1
        vm.startPrank(usr1);
        deal(address(tan), address(usr1), amount1);
        tan.approve(address(rsTanService), MAX_UINT);
        rsTanService.createLock(amount1, true, address(0));

        uint256 ts = block.timestamp;
        uint256 rateExpected = rewardAmount / uint256(1 weeks);
        uint256 timeToSkip = 3.5 days;

        vm.stopPrank();

        // Process the rewards
        vm.startPrank(owner);
        tgUSD.approve(address(rsTanService), MAX_UINT);
        deal(address(tgUSD), address(owner), rewardAmount);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: rewardAmount});
        rsTanService.processRewards(tokenAmounts);
        vm.stopPrank();

        (uint128 lastUpdateTime, uint128 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored) = rsTanService.rewardData(tgUSD);
        assertEq(lastUpdateTime, block.timestamp, "Last update time has changed because we created a lock");
        assertEq(periodFinish, ts + 1 weeks, "Period finish is the same ts");
        assertEq(rewardRate, rewardAmount / uint256(1 weeks));
        assertEq(rewardPerTokenStored, 0);
        assertEq(rsTanService.userRewardPerTokenPaid(1, tgUSD), 0);
        assertEq(rsTanService.rewards(1, tgUSD), 0);

        // Pass some time & create the second lock with usr2
        vm.startPrank(usr2);
        skip(timeToSkip);
        deal(address(tan), address(usr2), amount2);
        tan.approve(address(rsTanService), MAX_UINT);
        rsTanService.createLock(amount2, false, address(0));

        (lastUpdateTime, periodFinish, rewardRate, rewardPerTokenStored) = rsTanService.rewardData(tgUSD);
        assertEq(lastUpdateTime, block.timestamp, "A");
        assertEq(periodFinish, block.timestamp + timeToSkip, "B");
        assertEq(rewardRate, rateExpected, "Rate per token is incorrect");
        assertEq(rewardPerTokenStored, (timeToSkip * rateExpected * 1e18) / amount1, "Reward per token stored incorrect");
        // assertEq(rsTanService.userRewardPerTokenPaid(1, tgUSD), 0, "e");
        // assertEq(rsTanService.rewards(1, tgUSD), 0, "f");
        vm.stopPrank();

        skip(5 days);

        // rsTanService.processRewards();
        vm.prank(usr1);
        rsTanService.claimSimple(1, false);

        vm.prank(usr2);
        rsTanService.claimSimple(2, false);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RsTanService.NothingToClaim.selector));
        rsTanService.claimSimple(1, false);
    }

    function test_lock_claimMultiple() external {
        // Lock perma with user 1 and amount1
        uint208 amount1 = 10_000 ether;
        uint208 amount2 = 20_000 ether;
        uint208 amount3 = 20_000 ether;

        uint256 rewardAmount = 1_000 ether;
        // Create a lock with usr1
        vm.startPrank(usr1);
        deal(address(tan), address(usr1), amount1);
        tan.approve(address(rsTanService), MAX_UINT);
        rsTanService.createLock(amount1, true, address(0));

        uint256 ts = block.timestamp;
        uint256 rateExpected = rewardAmount / uint256(1 weeks);
        uint256 timeToSkip = 3.5 days;

        vm.stopPrank();

        // Process the rewards
        vm.startPrank(owner);
        tgUSD.approve(address(rsTanService), MAX_UINT);
        deal(address(tgUSD), address(owner), rewardAmount);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: rewardAmount});
        rsTanService.processRewards(tokenAmounts);
        vm.stopPrank();

        // Pass some time & create the second lock with usr2 and sent it to usr1
        vm.startPrank(usr2);
        skip(timeToSkip);
        deal(address(tan), address(usr2), amount2);
        tan.approve(address(rsTanService), MAX_UINT);
        rsTanService.createLock(amount2, false, address(0));
        rsTanERC721.transferFrom(usr2, usr1, 2);

        // Create a third token
        vm.startPrank(usr1);
        deal(address(tan), address(usr1), amount3);
        rsTanService.createLock(amount3, true, address(0));

        skip(5 days);

        verifyLostDeltaRelERC20(tgUSD, address(rsTanService), rewardAmount, 10 ** 3); // 0.000000000000100%
        verifyReceiveDeltaRelERC20(tgUSD, usr1, rewardAmount, 10 ** 3); // 0.000000000000100%

        rsTanService.claimMultiple(Array.memoryUint256([uint256(1), uint256(2), uint256(3)]), false);
        assertERC20Tracking();
    }
}

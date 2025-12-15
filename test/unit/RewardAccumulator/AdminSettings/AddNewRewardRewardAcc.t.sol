// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract AddNewRewardRewardAcc is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCryptoSwapLP.USDC_WBTC_ETH;
    ConvexCrvLPMarket public market;
    RCParams public rcParam;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
        rcParam = rewardAccumulator.getRCParams(address(market));
    }

    function test_addNewRewards_success() external {
        vm.startPrank(owner);
        IERC20[] memory tokensToAdd = new IERC20[](2);
        tokensToAdd[0] = AddrClassicERC20.DOLA;
        tokensToAdd[1] = AddrClassicERC20.USDT;

        rewardAccumulator.addNewRewards(address(market), tokensToAdd);

        IERC20[] memory tokens = rewardAccumulator.getRewardTokens(address(market));
        assertEq(tokens.length, 4);
        assertEq(address(tokens[2]), address(AddrClassicERC20.DOLA));
        assertEq(address(tokens[3]), address(AddrClassicERC20.USDT));
    }

    uint256[] processed;
    uint256[] totalProcessed;
    uint256[] alreadyStreamed;
    function test_addNewRewards_after_creation() external {
        uint256 amountStaked = 100 ether;
        uint256 borrowed = 20_000 ether;
        deal(address(collatToken), usr1, amountStaked * 2);
        deal(address(collatToken), usr2, amountStaked * 2);

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(amountStaked * 2, borrowed, false);

        vm.startPrank(usr2);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(amountStaked, borrowed, false);

        vm.startPrank(owner);
        uint256 distributed = 10_000 ether;
        for (uint256 i; i < rewardAccumulator.getRewardTokens(address(market)).length; i++) {
            IERC20 token = rewardAccumulator.rewardTokens(address(market), i);
            deal(address(token), address(market), distributed);
        }
        // At this moment only the rewards distributed just before are streaming
        rewardAccumulator.processRewards(address(market), usr1);

        skip(3.5 days);

        // Claim the rewards from Convex before the process on our side to determine exactly how much is distributed
        vm.startPrank(address(market));
        market.cvxRewardToken().getReward();

        processed.push(AddrClassicERC20.CRV.balanceOf(address(market)));
        processed.push(AddrClassicERC20.CVX.balanceOf(address(market)));
        processed.push(distributed);

        totalProcessed.push(distributed + AddrClassicERC20.CRV.balanceOf(address(market)));
        totalProcessed.push(distributed + AddrClassicERC20.CVX.balanceOf(address(market)));
        totalProcessed.push(distributed);

        alreadyStreamed.push(distributed + AddrClassicERC20.CRV.balanceOf(address(market)) / 2);
        alreadyStreamed.push(distributed + AddrClassicERC20.CVX.balanceOf(address(market)) / 2);
        alreadyStreamed.push(distributed / 2);

        vm.startPrank(owner);
        IERC20[] memory tokensToAdd = new IERC20[](1);
        tokensToAdd[0] = AddrClassicERC20.DOLA;

        rewardAccumulator.addNewRewards(address(market), tokensToAdd);

        deal(address(AddrClassicERC20.DOLA), address(market), distributed);

        uint256 rewardCutPercentage = rewardAccumulator.lastRewardCuts(address(market));

        for (uint256 i; i < 3; i++) {
            uint256 harvesterRewards = (processed[i] * rcParam.harvestFeePercentage) / 100_000;
            IERC20 token = rewardAccumulator.rewardTokens(address(market), i);

            verifyReceiveDeltaAbsERC20(token, usr4, harvesterRewards, 1_000_000);
            verifyReceiveDeltaAbsERC20(token, address(rewardAccumulator), processed[i] - harvesterRewards, 1_000_000);
            verifyLostDeltaAbsERC20(token, address(market), processed[i], 1_000_000);
        }
        rewardAccumulator.processRewards(address(market), usr4);

        assertERC20Tracking();

        for (uint256 i; i < 3; i++) {
            uint256 rewardProcessed = totalProcessed[i];

            uint256 harvesterRewards = (rewardProcessed * rcParam.harvestFeePercentage) / 100_000;

            uint256 rewardPostHarvest = rewardProcessed - harvesterRewards;

            uint256 rewardCut = (rewardPostHarvest * rewardCutPercentage) / 100_000;

            IERC20 token = rewardAccumulator.rewardTokens(address(market), i);

            assertEq(rewardCut, rewardAccumulator.cutFeeForToken(token));

            verifyReceiveDeltaRelERC20(token, usr1, (2 * (rewardPostHarvest - rewardCut)) / 3, 1e10);
            verifyReceiveDeltaRelERC20(token, usr2, (rewardPostHarvest - rewardCut) / 3, 1e10);
        }
        vm.stopPrank();

        skip(7 days);

        // Claim User1 => Supposed to have fully the first distribution (only CRV and CVX) and the half of the second one ( all rewards )

        vm.prank(usr1);
        rewardAccumulator.claimSimple(address(market));

        // Claim USR2
        vm.prank(usr2);
        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();

        for (uint256 i; i < 3; i++) {
            IERC20 token = rewardAccumulator.rewardTokens(address(market), i);
            Reward memory rData = rewardAccumulator.getRewardData(address(market), token);

            assertEq(rewardAccumulator.lastTimeRewardApplicable(address(market), token), block.timestamp);
            assertEq(rewardAccumulator.rewardPerToken(address(market), token), rData.rewardPerTokenStored);
            assertEq(rewardAccumulator.getRewardForDuration(address(market), token), rData.rewardRate * 7 days);

            assertApproxEqAbs(0, token.balanceOf(address(rewardAccumulator)) - rewardAccumulator.cutFeeForToken(token), 1e6);
        }
    }

    function test_removeReward_1() external {
        vm.startPrank(owner);
        assertEq(rewardAccumulator.getRewardTokens(address(market)).length, 2);
        rewardAccumulator.removeReward(address(market), address(AddrClassicERC20.CVX));
        assertEq(rewardAccumulator.getRewardTokens(address(market)).length, 1);
        assertEq(address(rewardAccumulator.rewardTokens(address(market), 0)), address(AddrClassicERC20.CRV));
    }

    function test_removeReward_2() external {
        vm.startPrank(owner);
        assertEq(rewardAccumulator.getRewardTokens(address(market)).length, 2);
        rewardAccumulator.removeReward(address(market), address(AddrClassicERC20.CRV));
        assertEq(rewardAccumulator.getRewardTokens(address(market)).length, 1);
        assertEq(address(rewardAccumulator.rewardTokens(address(market), 0)), address(AddrClassicERC20.CVX));
    }

    function test_addNewRewards_fails_when_the_reward_is_already_added() external {
        vm.startPrank(owner);
        IERC20[] memory tokensToAdd = new IERC20[](2);
        tokensToAdd[0] = AddrClassicERC20.DOLA;
        tokensToAdd[1] = AddrClassicERC20.CRV;

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.RewardAlreadyAdded.selector, address(AddrClassicERC20.CRV)));
        rewardAccumulator.addNewRewards(address(market), tokensToAdd);
    }
}

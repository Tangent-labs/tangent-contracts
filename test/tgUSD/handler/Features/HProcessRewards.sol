// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../Base/HandlerBase.sol";

import "../../../../src/tgUSD/Market/abstract/MarketRewards.sol";

contract HProcessRewards is HandlerBase {
    MarketRewards marketRewards;

    constructor(address _sender, MarketRewards _market) HandlerBase(_sender, _market) {
        marketRewards = MarketRewards(address(_market));
    }

    function processRewards(address harvestFeeReceiver) external handler {
        IERC20[] memory rewardTokens = marketRewards.getRewardTokens();
        uint256 harvesterFeePercentage = marketRewards.harvesterFeePercentage();
        IRewardAccumulator rewardAccumulator = marketRewards.rewardAccumulator();
        uint256 rewardCut = marketRewards.rewardCutPercentage();

        uint256[] memory receivedByHarvestor = new uint256[](rewardTokens.length);
        uint256[] memory receivedByAccumulator = new uint256[](rewardTokens.length);
        uint256[] memory rewardCuts = new uint256[](rewardTokens.length);

        for (uint256 index; index < rewardTokens.length; index++) {
            IERC20 rewardToken = rewardTokens[index];

            receivedByHarvestor[index] = rewardToken.balanceOf(harvestFeeReceiver);
            receivedByAccumulator[index] = rewardToken.balanceOf(address(rewardAccumulator));
            rewardCuts[index] = rewardAccumulator.cutFeeForToken(rewardToken);
        }

        marketRewards.processRewards(harvestFeeReceiver);

        for (uint256 index; index < rewardTokens.length; index++) {
            IERC20 rewardToken = rewardTokens[index];

            receivedByHarvestor[index] = rewardToken.balanceOf(harvestFeeReceiver) - receivedByHarvestor[index];
            receivedByAccumulator[index] = rewardToken.balanceOf(address(rewardAccumulator)) - receivedByAccumulator[index];

            uint256 totalClaimed = receivedByHarvestor[index] + receivedByAccumulator[index];
            assertEq((totalClaimed * harvesterFeePercentage) / 100_000, receivedByHarvestor[index]);

            uint256 cutFee = (receivedByAccumulator[index] * rewardCut) / 100_000;
            // uint256 streamedRewards = receivedByAccumulator[index] - cutFee;

            assertEq(rewardAccumulator.cutFeeForToken(rewardToken) - rewardCuts[index], cutFee);
        }
    }
}

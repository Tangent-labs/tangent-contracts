// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../Base/HandlerBase.sol";

import "../../../src/USG/Utilities/RewardAccumulator.sol";

contract HProcessRewards is HandlerBase {
    MarketExternalActions marketRewards;
    RewardAccumulator rewardAccumulator;
    constructor(
        address _sender,
        MarketExternalActions _market,
        RewardAccumulator _rewardAccumulator,
        IERC20 _usg,
        MarketViewer _marketViewer
    ) HandlerBase(_sender, _market, _usg, _marketViewer) {
        marketRewards = MarketExternalActions(address(_market));
        rewardAccumulator = _rewardAccumulator;
    }

    function processRewards(address harvestFeeReceiver) external handler {
        IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(marketRewards));

        RCParams memory _rcParams = rewardAccumulator.getRCParams(address(marketRewards));

        uint256 harvesterFeePercentage = _rcParams.harvestFeePercentage;
        uint256 rewardCut = rewardAccumulator.lastRewardCuts(address(marketRewards));

        uint256[] memory receivedByHarvestor = new uint256[](rewardTokens.length);
        uint256[] memory receivedByAccumulator = new uint256[](rewardTokens.length);
        uint256[] memory rewardCuts = new uint256[](rewardTokens.length);

        for (uint256 index; index < rewardTokens.length; index++) {
            IERC20 rewardToken = rewardTokens[index];

            receivedByHarvestor[index] = rewardToken.balanceOf(harvestFeeReceiver);
            receivedByAccumulator[index] = rewardToken.balanceOf(address(rewardAccumulator));
            rewardCuts[index] = rewardAccumulator.cutFeeForToken(rewardToken);
        }

        rewardAccumulator.processRewards(address(marketRewards), harvestFeeReceiver);

        for (uint256 index; index < rewardTokens.length; index++) {
            IERC20 rewardToken = rewardTokens[index];

            receivedByHarvestor[index] = rewardToken.balanceOf(harvestFeeReceiver) - receivedByHarvestor[index];
            receivedByAccumulator[index] = rewardToken.balanceOf(address(rewardAccumulator)) - receivedByAccumulator[index];

            uint256 totalClaimed = receivedByHarvestor[index] + receivedByAccumulator[index];
            assertApproxEqAbs((totalClaimed * harvesterFeePercentage) / 100_000, receivedByHarvestor[index], 1_000_000, "Verify amount claimed by harvestor");

            uint256 cutFee = (receivedByAccumulator[index] * rewardCut) / 100_000;
            // uint256 streamedRewards = receivedByAccumulator[index] - cutFee;

            assertApproxEqAbs(rewardAccumulator.cutFeeForToken(rewardToken) - rewardCuts[index], cutFee, 1_000_000, "Verify cut fee computation");
        }
    }
}

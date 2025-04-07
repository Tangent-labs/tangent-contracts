// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenAmount, IERC20} from "../ICommonStruct.sol";

struct Reward {
    uint128 lastUpdateTime;
    uint128 periodFinish;
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
}
interface IRewardAccumulator {
    function cutFeeForToken(IERC20 token) external view returns (uint256);

    function getRewardTokens(address market) external view returns (IERC20[] memory);

    function harvesterFeePercentage(address market) external view returns (uint256);

    function rewardData(address market, IERC20 token) external view returns (uint128, uint128, uint256, uint256);

    function updateRewards(address account) external;

    function processRewards(address harvestFeeReceiver, TokenAmount[] memory rewardAmounts) external;
}

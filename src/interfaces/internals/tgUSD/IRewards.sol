// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, TokenAmount} from "../ICommonStruct.sol";

struct Reward {
    uint128 lastUpdateTime;
    uint128 periodFinish;
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
}

interface IRewards {
    function rewardData(address token) external view returns (uint128, uint128, uint256, uint256);
    function getRewardTokens() external view returns (IERC20[] memory);
    function harvesterFeePercentage() external view returns (uint256);
    function claimableRewards(address account) external view returns (TokenAmount[] memory);
    function rewardCutPercentage() external view returns (uint256);
    function getAndUpdateRewards(address account) external returns (TokenAmount[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, ICommonStruct} from "../ICommonStruct.sol";

interface IRewards {
    struct Reward {
        uint128 lastUpdateTime;
        uint128 periodFinish;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    function rewardData(address token) external view returns (uint128, uint128, uint256, uint256);
    function getRewardTokens() external view returns (IERC20[] memory);
    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);
    function harvesterFeePercentage() external view returns (uint256);
    function claimableRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);
}

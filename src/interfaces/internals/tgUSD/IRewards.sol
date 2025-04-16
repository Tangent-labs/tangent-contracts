// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, TokenAmount} from "../ICommonStruct.sol";

struct Reward {
    uint128 lastUpdateTime;
    uint128 periodFinish;
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
}

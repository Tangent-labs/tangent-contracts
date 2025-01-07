// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, ICommonStruct} from "../ICommonStruct.sol";

interface IRewards {
    function getRewardTokens() external view returns (IERC20[] memory);
    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);
}

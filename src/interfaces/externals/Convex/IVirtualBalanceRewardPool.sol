// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

interface IVirtualBalanceRewardPool is IERC20Metadata {
    function rewardRate() external view returns (uint256);
    function rewardToken() external view returns (IERC20Metadata);
}

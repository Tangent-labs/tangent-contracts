// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRewardsHandler {
    function process_rewards(bool take_snapshot) external;
}

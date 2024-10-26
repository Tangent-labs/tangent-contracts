// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGauge is IERC20 {
    function staking_token() external view returns (address);
    function deposit(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function withdraw(uint256) external;
    function claim_rewards() external;
    function reward_tokens(uint256) external view returns (address); //v2
    function rewarded_token() external view returns (address); //v1
}

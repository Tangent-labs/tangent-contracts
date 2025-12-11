// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IStakeDaoVaultV2 is IERC20Metadata {
    function ACCOUNTANT() external view returns (address);
    function DEFAULT_REWARDS_DURATION() external view returns (uint32);
    function POLICY() external view returns (uint8);
    function PROTOCOL_CONTROLLER() external view returns (address);
    function PROTOCOL_ID() external view returns (bytes4);
    function accountData(address account, address rewardToken) external view returns (uint128 rewardPerTokenPaid, uint128 claimable);
    function addRewardToken(address rewardToken, address distributor) external;
    function allocator() external view returns (address _allocator);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function checkpoint(address account) external;
    function claim(address[] calldata tokens, address receiver) external returns (uint256[] memory amounts);
    function claim(address account, address[] calldata tokens, address receiver) external returns (uint256[] memory amounts);
    function convertToAssets(uint256 shares) external pure returns (uint256);
    function convertToShares(uint256 assets) external pure returns (uint256);
    function decimals() external view returns (uint8);
    function deposit(uint256 assets, address receiver, address referrer) external returns (uint256);
    function deposit(address account, address receiver, uint256 assets, address referrer) external returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function depositRewards(address rewardToken, uint128 amount) external;
    function earned(address account, address token) external view returns (uint128);
    function gauge() external view returns (address _gauge);
    function getClaimable(address token, address account) external view returns (uint128);
    function getLastUpdateTime(address token) external view returns (uint32);
    function getPeriodFinish(address token) external view returns (uint32);
    function getRewardPerTokenPaid(address token, address account) external view returns (uint128);
    function getRewardPerTokenStored(address token) external view returns (uint128);
    function getRewardRate(address token) external view returns (uint128);
    function getRewardTokens() external view returns (address[] memory);
    function getRewardsDistributor(address token) external view returns (address);
    function isRewardToken(address rewardToken) external view returns (bool);
    function lastTimeRewardApplicable(address token) external view returns (uint256);
    function maxDeposit(address) external pure returns (uint256);
    function maxMint(address _account) external pure returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function mint(uint256 shares, address receiver, address referrer) external returns (uint256);
    function name() external view returns (string memory);
    function previewDeposit(uint256 shares) external pure returns (uint256);
    function previewMint(uint256 assets) external pure returns (uint256);
    function previewRedeem(uint256 shares) external pure returns (uint256);
    function previewWithdraw(uint256 assets) external pure returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function resumeVault() external;
    function rewardData(
        address rewardToken
    ) external view returns (address rewardsDistributor, uint32 lastUpdateTime, uint32 periodFinish, uint128 rewardRate, uint128 rewardPerTokenStored);
    function rewardPerToken(address token) external view returns (uint128);
    function strategy() external view returns (address _strategy);
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}

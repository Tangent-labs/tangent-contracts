// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPendleSYToken is IERC20 {
    // Errors
    error SYInsufficientSharesOut(uint256 actualSharesOut, uint256 requiredSharesOut);
    error SYInsufficientTokenOut(uint256 actualTokenOut, uint256 requiredTokenOut);
    error SYInvalidTokenIn(address token);
    error SYInvalidTokenOut(address token);
    error SYZeroDeposit();
    error SYZeroRedeem();

    // Events
    event ClaimRewards(address indexed user, address[] rewardTokens, uint256[] rewardAmounts);
    event Deposit(address indexed caller, address indexed receiver, address indexed tokenIn, uint256 amountDeposited, uint256 amountSyOut);
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event NewStakingRewards(address newStakingRewards);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Redeem(address indexed caller, address indexed receiver, address indexed tokenOut, uint256 amountSyToRedeem, uint256 amountTokenOut);
    event Unpaused(address account);

    // Functions
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function INST() external view returns (address);
    function LIQUIDITY() external view returns (address);
    function accruedRewards(address user) external view returns (uint256[] memory rewardAmounts);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function assetInfo() external view returns (uint8 assetType, address assetAddress, uint8 assetDecimals);
    function balanceOf(address account) external view returns (uint256);
    function claimOwnership() external;
    function claimRewards(address user) external returns (uint256[] memory rewardAmounts);
    function decimals() external view returns (uint8);
    function deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 minSharesOut) external payable returns (uint256 amountSharesOut);
    function eip712Domain()
        external
        view
        returns (bytes1 fields, string memory name, string memory version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] memory extensions);
    function exchangeRate() external view returns (uint256);
    function getRewardTokens() external view returns (address[] memory rewardTokens);
    function getTokensIn() external view returns (address[] memory res);
    function getTokensOut() external view returns (address[] memory res);
    function initialize(string memory _name, string memory _symbol) external;
    function isValidTokenIn(address token) external view returns (bool);
    function isValidTokenOut(address token) external view returns (bool);
    function lastRewardBlock() external view returns (uint256);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit) external view returns (uint256 amountSharesOut);
    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem) external view returns (uint256 amountTokenOut);
    function redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 minTokenOut, bool burnFromInternalBalance) external returns (uint256 amountTokenOut);
    function rewardIndexesCurrent() external returns (uint256[] memory indexes);
    function rewardIndexesStored() external view returns (uint256[] memory indexes);
    function rewardState(address, address) external view returns (uint128 index, uint128 lastBalance);
    function setStakingRewards(address _newStakingRewards) external;
    function stakingRewards() external view returns (address);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
    function unpause() external;
    function userReward(address, address) external view returns (uint128 index, uint128 accrued);
    function yieldToken() external view returns (address);
}

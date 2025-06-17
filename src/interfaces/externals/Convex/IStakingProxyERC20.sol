// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../FXN/ISharedLiquidityGauge.sol";
interface IStakingProxyERC20 {
    function FEE_DENOMINATOR() external view returns (uint256);
    function deposit(uint256 _amount, bool _manage) external;
    function deposit(uint256 _amount) external;
    function earned() external returns (address[] memory token_addresses, uint256[] memory total_earned);
    function execute(address _to, uint256 _value, bytes memory _data) external returns (bool, bytes memory);
    function feeRegistry() external view returns (address);
    function fxn() external view returns (address);
    function fxnMinter() external view returns (address);
    function gaugeAddress() external view returns (ISharedLiquidityGauge);
    function getReward() external;
    function getReward(bool _claim, address[] memory _tokenList) external;
    function getReward(bool _claim) external;
    function initialize(address _owner, uint256 _pid) external;
    function owner() external view returns (address);
    function pid() external view returns (uint256);
    function poolRegistry() external view returns (address);
    function rewards() external view returns (address);
    function setVeFXNProxy(address _proxy) external;
    function stakingToken() external view returns (address);
    function transferTokens(address[] memory _tokenList) external;
    function usingProxy() external view returns (address);
    function vaultType() external pure returns (uint8);
    function vaultVersion() external pure returns (uint256);
    function vefxnProxy() external view returns (address);
    function withdraw(uint256 _amount) external;
}

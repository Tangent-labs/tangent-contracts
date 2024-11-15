// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IStakingProxyRelancePool {
    function FEE_DENOMINATOR() external view returns (uint256);
    function deposit(uint256 _amount) external;
    function depositBase(uint256 _amount, uint256 _minAmountOut) external;
    function depositFxUsd(uint256 _amount) external;
    function earned() external returns (address[] memory token_addresses, uint256[] memory total_earned);
    function execute(address _to, uint256 _value, bytes memory _data) external returns (bool, bytes memory);
    function feeRegistry() external view returns (address);
    function fxn() external view returns (address);
    function fxnMinter() external view returns (address);
    function fxusd() external view returns (address);
    function gaugeAddress() external view returns (address);
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
    function withdrawAsBase(uint256 _amount, address _fxfacet, address _fxconverter) external;
    function withdrawFxUsd(uint256 _amount) external;
}

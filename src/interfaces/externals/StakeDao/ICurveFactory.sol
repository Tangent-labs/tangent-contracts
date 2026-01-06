// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ICurveFactory {
    function ACCOUNTANT() external view returns (address);
    function BOOSTER() external view returns (address);
    function CONVEX_SIDECAR_FACTORY() external view returns (address);
    function CVX() external view returns (address);
    function GATEWAY() external view returns (address);
    function GAUGE_CONTROLLER() external view returns (address);
    function LOCKER() external view returns (address);
    function OLD_STRATEGY() external view returns (address);
    function PROTOCOL_CONTROLLER() external view returns (address);
    function PROTOCOL_ID() external view returns (bytes4);
    function REWARD_RECEIVER_IMPLEMENTATION() external view returns (address);
    function REWARD_TOKEN() external view returns (address);
    function REWARD_VAULT_IMPLEMENTATION() external view returns (address);
    function create(uint256 _pid) external returns (address vault, address rewardReceiver, address sidecar);
    function createVault(address gauge) external returns (address vault, address rewardReceiver);
    function syncRewardTokens(address gauge) external;
}

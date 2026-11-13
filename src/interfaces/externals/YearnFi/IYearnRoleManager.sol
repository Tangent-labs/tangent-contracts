// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Yearn V3 RoleManager (e.g. 0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41).
interface IYearnRoleManager {
    function getDaddy() external view returns (address);
    function getBrain() external view returns (address);
    function getKeeper() external view returns (address);
    function getAccountant() external view returns (address);
    function addNewVault(address vault, uint256 category) external;
    function isVaultsRoleManager(address vault) external view returns (bool);
}

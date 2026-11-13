// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Yearn RouterV2 tokenized strategy (deposits into a Yearn V2 vault).
interface IRouterV2 {
    function V2_VAULT() external view returns (address);
    function allowed(address) external view returns (bool);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function management() external view returns (address);
    function pendingManagement() external view returns (address);
    function keeper() external view returns (address);
    function emergencyAdmin() external view returns (address);
    function performanceFeeRecipient() external view returns (address);
    function performanceFee() external view returns (uint16);
    function profitMaxUnlockTime() external view returns (uint256);
    function setPerformanceFee(uint16) external;
    function setProfitMaxUnlockTime(uint256) external;
    function setAllowed(address, bool) external;
    function setKeeper(address) external;
    function setPerformanceFeeRecipient(address) external;
    function setEmergencyAdmin(address) external;
    function setPendingManagement(address) external;
    function acceptManagement() external;
    function report() external returns (uint256 profit, uint256 loss);
}

interface IYearnV2Registry {
    function latestVault(address token) external view returns (address);
}

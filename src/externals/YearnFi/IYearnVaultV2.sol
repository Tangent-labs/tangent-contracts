// SPDX-License-Identifier: AGLP-3.0
pragma solidity ^0.8.19;

interface IYearnVaultV2 {
    function harvest() external;

    function deposit(uint256 amount) external returns (uint256);

    function withdraw(uint256) external returns (uint256);

    function withdraw(
        uint256 amount,
        address account,
        uint256 maxLoss
    ) external returns (uint256);

    function token() external view returns (address);

    function pricePerShare() external view returns (uint256);

    function decimals() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function lockedProfitDegradation() external view returns (uint256);

    function lastReport() external view returns (uint256);

    function lockedProfit() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function withdrawalQueue(uint256) external view returns (address);

    function depositLimit() external view returns (uint256);

    function strategist() external view returns (address);
}

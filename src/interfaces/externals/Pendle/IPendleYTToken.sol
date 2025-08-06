// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPendleYTToken {
    function PT() external view returns (address);
    function SY() external view returns (address);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function doCacheIndexSameBlock() external view returns (bool);
    function expiry() external view returns (uint256);
    function factory() external view returns (address);
    function getPostExpiryData()
        external
        view
        returns (uint256 firstPYIndex, uint256 totalSyInterestForTreasury, uint256[] memory firstRewardIndexes, uint256[] memory userRewardOwed);
    function getRewardTokens() external view returns (address[] memory);
    function isExpired() external view returns (bool);
    function mintPY(address receiverPT, address receiverYT) external returns (uint256 amountPYOut);
    function mintPYMulti(address[] memory receiverPTs, address[] memory receiverYTs, uint256[] memory amountSyToMints) external returns (uint256[] memory amountPYOuts);
    function name() external view returns (string memory);
    function postExpiry() external view returns (uint128 firstPYIndex, uint128 totalSyInterestForTreasury);
    function pyIndexCurrent() external returns (uint256 currentIndex);
    function pyIndexLastUpdatedBlock() external view returns (uint128);
    function pyIndexStored() external view returns (uint256);
    function redeemDueInterestAndRewards(address user, bool redeemInterest, bool redeemRewards) external returns (uint256 interestOut, uint256[] memory rewardsOut);
    function redeemInterestAndRewardsPostExpiryForTreasury() external returns (uint256 interestOut, uint256[] memory rewardsOut);
    function redeemPY(address receiver) external returns (uint256 amountSyOut);
    function redeemPYMulti(address[] memory receivers, uint256[] memory amountPYToRedeems) external returns (uint256[] memory amountSyOuts);
    function rewardIndexesCurrent() external returns (uint256[] memory);
    function setPostExpiryData() external;
    function syReserve() external view returns (uint256);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function userInterest(address) external view returns (uint128 index, uint128 accrued);
    function userReward(address, address) external view returns (uint128 index, uint128 accrued);
}

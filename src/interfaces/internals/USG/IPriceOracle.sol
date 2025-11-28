// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceOracle {
    function latestAnswer(bool isNoFailMode) external view returns (uint256);

    function latestAnswerUpdate(bool isNoFailMode) external returns (uint256);

    function decimals() external view returns (uint8);
}

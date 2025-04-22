// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceOracle {
    function latestAnswer() external view returns (uint256);

    function decimals() external view returns (uint8);
}

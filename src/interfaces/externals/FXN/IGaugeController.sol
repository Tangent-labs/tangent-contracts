// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IGaugeController {
    function gauge_relative_weight(address gauge, uint256 time) external view returns (uint256);
}

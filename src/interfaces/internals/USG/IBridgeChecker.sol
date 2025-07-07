// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeChecker {
    function isBridgingAllowed(address sender, address refundAddress, uint256 amountLD, uint256 minAmountLD, uint32 destEid) external view returns (bool);
}

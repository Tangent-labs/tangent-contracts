// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISociabilization {
    function socFeePercentage() external view returns (uint256);

    function socFeePending() external view returns (uint256);
}

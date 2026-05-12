// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct TokenVestingInfo {
    uint256 term;
    uint256 claimable;
    uint256 pending;
}
interface IBondDepository {
    function getTokenVestingInfo(uint256 tokenId) external view returns (TokenVestingInfo memory);
}

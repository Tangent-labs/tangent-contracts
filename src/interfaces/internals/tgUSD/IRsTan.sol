// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRsTan {
    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external;

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external;
}

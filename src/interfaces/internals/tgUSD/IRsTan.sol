// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

interface IRsTan is IERC721Enumerable {
    function totalSupplyRsTan() external view returns (uint256);

    function locks(uint256 tokenId) external view returns (uint48, uint208);

    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external;

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external;
}

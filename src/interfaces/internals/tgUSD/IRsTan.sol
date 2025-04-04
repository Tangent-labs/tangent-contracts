// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenAmount} from "../ICommonStruct.sol";
interface IRsTan {
    function totalSupplyRsTan() external view returns (uint256);

    function locks(uint256 tokenId) external view returns (uint48, uint208);

    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external;

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external;

    function claimableRewards(uint256 tokenId) external view returns (TokenAmount[] memory);
}

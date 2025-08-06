// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenAmount} from "../ICommonStruct.sol";
import {Reward} from "./IRewardAccumulator.sol";
interface IVsTan is IERC721Enumerable {
    function totalSupplyVsTan() external view returns (uint256);

    function locks(uint256 tokenId) external view returns (uint48, uint208);

    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external;

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external;

    function claimableRewards(uint256 tokenId) external view returns (TokenAmount[] memory);

    function getRewardData(IERC20 erc20) external view returns (Reward memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
interface IRsTanERC721 is IERC721Enumerable {
    function mintForCreate(address receiver) external returns (uint256);
    function mintForSplit(address receiver, uint256 tokenId) external returns (uint256);

    function burn(uint256 tokenId) external;
    function burnCheckCallerOwner(uint256 tokenId, address caller) external;
    function burnAndGetOwner(uint256 tokenId) external returns (address);
    function burnForMerge(uint256 tokenIdA, uint256 tokenIdB, address caller) external;

    function verifyTokenIdsOwned(address caller, uint256[] calldata positionIds) external view;
}

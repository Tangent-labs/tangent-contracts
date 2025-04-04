// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IRsTanERC721} from "../../interfaces/internals/tgUSD/IRsTanERC721.sol";

import {Reward, TokenAmount} from "../../interfaces/internals/tgUSD/IRewards.sol";

import {LightOwnable} from "../Utilities/LightOwnable.sol";

import "forge-std/console.sol";
/// @notice
contract RsTanERC721 is ERC721Enumerable, LightOwnable, IRsTanERC721 {
    /// @notice The next token ID to be minted.
    uint256 public nextId;

    address public rsTanService;

    constructor(address _owner) ERC721("RsTanService", "RsTanService") {
        nextId = 1;
        _transferOwnership(_owner);
    }

    modifier onlyService() {
        require(rsTanService == msg.sender, CallerNotService());
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId, address caller) {
        require(ownerOf(tokenId) == caller, NotTokenOwner());
        _;
    }
    error CallerNotService();
    error NotTokenOwner();

    /**
     * @notice Mint a new RsTanService token
     * @dev    Only callable by the service contract
     * @param receiver Receiver of the NFT
     */
    function mintForCreate(address receiver) external onlyService returns (uint256) {
        uint256 tokenId = nextId++;
        _mint(receiver, tokenId);
        return tokenId;
    }

    /**
     * @notice Mint a new RsTanService token
     * @dev    Only callable by the service contract
     * @param receiver Receiver of the NFT
     */
    function mintForSplit(address receiver, uint256 tokenId) external onlyService onlyTokenOwner(tokenId, receiver) returns (uint256) {
        tokenId = nextId++;
        _mint(receiver, tokenId);
        return tokenId;
    }

    function burnForMerge(uint256 tokenIdA, uint256 tokenIdB, address caller) external onlyService onlyTokenOwner(tokenIdA, caller) onlyTokenOwner(tokenIdB, caller) {
        _burn(tokenIdB);
    }

    function burnForUnlock(uint256 tokenId, address caller) external onlyService onlyTokenOwner(tokenId, caller) {
        _burn(tokenId);
    }

    function burKickPosition(uint256 tokenId) external onlyService returns (address) {
        address _owner = ownerOf(tokenId);
        _burn(tokenId);
        return _owner;
    }

    function verifyTokenIdsOwned(address caller, uint256[] calldata positionIds) external view {
        for (uint256 i; i < positionIds.length; ) {
            require(caller == ownerOf(positionIds[i]), NotTokenOwner());
            unchecked {
                ++i;
            }
        }
    }

    function setService(address _rsTanService) external onlyOwner {
        rsTanService = _rsTanService;
    }
}

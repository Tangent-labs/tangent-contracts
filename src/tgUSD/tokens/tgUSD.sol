// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import {ItgUSD} from "../../interfaces/internals/tgUSD/ItgUSD.sol";

import "forge-std/console.sol";
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract tgUSD is OFT, ItgUSD {
    mapping(address => bool) public isMinterBurner;

    error CallerNotMinterBurner();

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _owner
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_owner) {}

    function mint(address to, uint256 amount) external {
        require(isMinterBurner[msg.sender], CallerNotMinterBurner());
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        require(isMinterBurner[msg.sender], CallerNotMinterBurner());
        _burn(from, amount);
    }

    function burnFrom(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function toggleMintersBurners(address[] calldata mintersBurners) external onlyOwner {
        for (uint256 i; i < mintersBurners.length; ) {
            address minterBurner = mintersBurners[i];
            isMinterBurner[minterBurner] = !isMinterBurner[minterBurner];
            unchecked {
                ++i;
            }
        }
    }
}

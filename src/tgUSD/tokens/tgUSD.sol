// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import {ItgUSD} from "../../interfaces/internals/tgUSD/ItgUSD.sol";

import "forge-std/console.sol";
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract tgUSD is OFT, ItgUSD {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// TODO Callable only by market
    function burnFrom(address to, uint256 amount) external {
        _burn(to, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {ERC20, ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "forge-std/console.sol";
/// @notice
contract Tan is ERC20Capped {
    error ZeroAmount();
    constructor() ERC20Capped(10_000_000 ether) ERC20("Tangent Token", "TAN") {}

    //TODO See how to do the mint
    function mint(address to, uint256 amountIn) external {
        require(amountIn != 0, ZeroAmount());
        _mint(to, amountIn);
    }

    function burn(uint256 amount) external {
        require(amount != 0, ZeroAmount());
        _burn(msg.sender, amount);
    }
}

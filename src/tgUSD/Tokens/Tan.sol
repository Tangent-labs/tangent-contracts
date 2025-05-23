// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {ERC20, ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "forge-std/console.sol";
/// @notice
contract Tan is ERC20 {
    error ZeroAmount();

    /**
     * @notice All tokens are minted at launch on the DAO.
     *         The DAO creates the liquidity and dispatch TAN to the airdrop.
     * @param dao address receiving the totality of the supply at launch.
     */
    constructor(address dao) ERC20("Tangent Token", "TAN") {
        _mint(dao, 10_000_000 ether);
    }

    /**
     * @notice Burn TAN tokens from the caller
     * @param amount Amount of TAN to burn
     */
    function burn(uint256 amount) external {
        require(amount != 0, ZeroAmount());
        _burn(msg.sender, amount);
    }
}

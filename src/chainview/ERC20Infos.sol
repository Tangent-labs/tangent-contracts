// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC20Infos {
    struct ERC20Info {
        IERC20Metadata token;
        uint256 amount;
        uint256 decimals;
        string symbol;
    }

    function getERC20Infos(IERC20 erc20, uint256 amount) public view returns (ERC20Info memory) {
        IERC20Metadata erc20Meta = IERC20Metadata(address(erc20));
        return ERC20Info({token: erc20Meta, amount: amount, decimals: erc20Meta.decimals(), symbol: erc20Meta.symbol()});
    }
}

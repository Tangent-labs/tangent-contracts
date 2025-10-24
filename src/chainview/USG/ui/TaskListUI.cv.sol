// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";

contract TaskListUI {
    error TaskListUIError(uint256[] balances);

    constructor(address account, IDebtIR[] memory markets, IERC20[] memory tokens) {
        uint256[] memory balances = new uint256[](tokens.length + 1);

        for (uint256 i; i < tokens.length; ) {
            balances[i] = tokens[i].balanceOf(account);
            unchecked {
                ++i;
            }
        }
        uint256 debt;
        for (uint256 i; i < markets.length; ) {
            debt += markets[i].userDebt(account);
            unchecked {
                ++i;
            }
        }

        balances[tokens.length] = debt;
        revert TaskListUIError(balances);
    }
}

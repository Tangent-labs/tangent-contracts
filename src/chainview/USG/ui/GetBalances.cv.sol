// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract GetBalances {
    error GetBalancesError(uint256[] balances);
    constructor(address user, IERC20[] memory tokens) {
        uint256[] memory balances = new uint256[](tokens.length);

        for (uint256 i; i < tokens.length; ) {
            IERC20 token = tokens[i];
            balances[i] = (address(token) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) ? user.balance : token.balanceOf(user);
            unchecked {
                ++i;
            }
        }
        revert GetBalancesError(balances);
    }
}

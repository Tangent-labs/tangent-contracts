// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct TokenBalance {
    IERC20 token;
    uint256 balance;
}

struct TokenBalancesForBoostOut {
    address user;
    TokenBalance[] tokenBalance;
}

contract TokenBalancesForMultipleUsers {
    error TokenBalancesForBoostError(uint256 timestamp, TokenBalancesForBoostOut[] out);

    constructor(IERC20[] memory tokens, address[] memory users) {
        revert TokenBalancesForBoostError(block.timestamp, _getOut(tokens, users));
    }

    function _getOut(IERC20[] memory tokens, address[] memory users) internal view returns (TokenBalancesForBoostOut[] memory) {
        uint256 tokenLen = tokens.length;
        uint256 usrLen = users.length;

        TokenBalancesForBoostOut[] memory out = new TokenBalancesForBoostOut[](usrLen);

        for (uint256 i = 0; i < usrLen; i++) {
            address usr = users[i];
            TokenBalance[] memory tokenBalances = new TokenBalance[](tokenLen);
            uint256 count = 0;

            for (uint256 j = 0; j < tokenLen; j++) {
                IERC20 token = tokens[j];
                uint256 bal = token.balanceOf(usr);

                if (bal > 0) {
                    tokenBalances[count] = TokenBalance({token: token, balance: bal});
                    count++;
                }
            }

            assembly {
                mstore(tokenBalances, count)
            }

            out[i] = TokenBalancesForBoostOut({user: usr, tokenBalance: tokenBalances});
        }

        return out;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BalancesAllowances {
    struct InputBalancesAllowances {
        IERC20 token;
        address[] spenders;
    }

    struct OutputBalanceAllowances {
        IERC20 token;
        uint256 balance;
        Allowance[] allowances;
    }

    struct Allowance {
        address spender;
        uint256 allowance;
    }

    function getBalancesAllowances(address user, InputBalancesAllowances[] memory ibas) public view returns (OutputBalanceAllowances[] memory) {
        OutputBalanceAllowances[] memory obas = new OutputBalanceAllowances[](ibas.length);

        for (uint256 i = 0; i < ibas.length; ) {
            InputBalancesAllowances memory iba = ibas[i];
            IERC20 token = iba.token;

            Allowance[] memory allowances = new Allowance[](iba.spenders.length);

            for (uint256 j = 0; j < iba.spenders.length; ) {
                address spender = iba.spenders[j];

                allowances[j] = Allowance({spender: spender, allowance: token.allowance(user, spender)});

                unchecked {
                    ++j;
                }
            }

            obas[i] = OutputBalanceAllowances({token: iba.token, balance: iba.token.balanceOf(user), allowances: allowances});
            unchecked {
                ++i;
            }
        }

        return obas;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
abstract contract BalancesAllowances {
    uint256 MAX_UINT = uint256(int256(-1));

    function getBalancesAllowances(address user, InputBalancesAllowances[] memory ibas) public view returns (OutputBalanceAllowances[] memory) {
        OutputBalanceAllowances[] memory obas = new OutputBalanceAllowances[](ibas.length);

        for (uint256 i = 0; i < ibas.length; ) {
            InputBalancesAllowances memory iba = ibas[i];
            IERC20 token = iba.token;

            Allowance[] memory allowances = new Allowance[](iba.spenders.length);

            bool isEth = address(token) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

            for (uint256 j = 0; j < iba.spenders.length; ) {
                address spender = iba.spenders[j];

                uint256 allowance = isEth ? MAX_UINT : token.allowance(user, spender);

                allowances[j] = Allowance({spender: spender, allowance: allowance});

                unchecked {
                    ++j;
                }
            }
            uint256 balance = isEth ? user.balance : token.balanceOf(user);

            obas[i] = OutputBalanceAllowances({token: token, balance: balance, allowances: allowances});
            unchecked {
                ++i;
            }
        }

        return obas;
    }
}

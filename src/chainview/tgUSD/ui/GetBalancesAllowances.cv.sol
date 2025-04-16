// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances, OutputBalanceAllowances, InputBalancesAllowances} from "../../BalancesAllowances.sol";

contract GetBalancesAllowances is BalancesAllowances {
    error GetBalancesAllowancesError(OutputBalanceAllowances[] obas);
    constructor(address user, InputBalancesAllowances[] memory ibas) {
        revert GetBalancesAllowancesError(getBalancesAllowances(user, ibas));
    }
}

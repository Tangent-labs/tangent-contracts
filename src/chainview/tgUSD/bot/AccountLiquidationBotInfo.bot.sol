// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetAccountLiquidation} from "../GetAccountLiquidation.sol";

contract AccountLiquidationBotInfo is GetAccountLiquidation {
    error GetAccountLiquidationInfoError(LiquidationPositionsOut[] output);

    constructor(LendingPositionsIn[] memory usersMarkets) {
        revert GetAccountLiquidationInfoError(getLiquidationAccountInfo(usersMarkets));
    }
}

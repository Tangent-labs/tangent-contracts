// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetAccountLiquidation} from "../GetAccountLiquidation.sol";

import {IMarketViewer} from "../../../interfaces/internals/USG/IMarketViewer.sol";

contract GetActivePositionsStatus is GetAccountLiquidation {
    error MarketLiquidationBotInfoError(AccountLiquidationInfo[] output);

    constructor(LendingPositionsIn[] memory usersMarkets, IMarketViewer _marketViewer) {
        revert MarketLiquidationBotInfoError(getAccountLiquidationInfo(usersMarkets, _marketViewer));
    }
}

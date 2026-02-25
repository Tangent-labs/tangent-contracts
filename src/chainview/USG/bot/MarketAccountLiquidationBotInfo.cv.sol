// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetMarketLiquidation} from "../GetMarketLiquidation.sol";
import {GetAccountLiquidation} from "../GetAccountLiquidation.sol";

import {IMarketViewer} from "../../../interfaces/internals/USG/IMarketViewer.sol";

contract MarketAccountLiquidationBotInfo is GetMarketLiquidation, GetAccountLiquidation {
    struct MarketAccountLiquidationBotInfoOut {
        MarketLiquidationInfo[] markets;
        AccountLiquidationInfo[] accounts;
        uint256 blockNumber;
        uint256 blockTimestamp;
    }

    error MarketLiquidationBotInfoError(MarketAccountLiquidationBotInfoOut output);

    constructor(address[] memory markets, LendingPositionsIn[] memory usersMarkets, IMarketViewer _marketViewer) {
        MarketAccountLiquidationBotInfoOut memory out = MarketAccountLiquidationBotInfoOut({
            markets: getMarketsLiquidationInfo(markets),
            accounts: getAccountLiquidationInfo(usersMarkets, _marketViewer),
            blockNumber: block.number,
            blockTimestamp: block.timestamp
        });

        revert MarketLiquidationBotInfoError(out);
    }
}

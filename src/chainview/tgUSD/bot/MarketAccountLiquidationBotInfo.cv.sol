// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetMarketLiquidation} from "../GetMarketLiquidation.sol";
import {GetAccountLiquidation} from "../GetAccountLiquidation.sol";

contract MarketAccountLiquidationBotInfo is GetMarketLiquidation, GetAccountLiquidation {

    struct MarketAccountLiquidationBotInfoOut {
        MarketLiquidationInfo[] markets;
        AccountLiquidationInfo[] accounts;
    }


    error MarketLiquidationBotInfoError(MarketAccountLiquidationBotInfoOut output);

    constructor(address[] memory markets, LendingPositionsIn[] memory usersMarkets) {

        MarketAccountLiquidationBotInfoOut  memory out = MarketAccountLiquidationBotInfoOut({
            markets :  getMarketsLiquidationInfo(markets),
            accounts :  getAccountLiquidationInfo(usersMarkets)
        });

        revert  MarketLiquidationBotInfoError(out);
    }
}

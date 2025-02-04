// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetLiquidationMarketInfo} from "../GetLiquidationMarketInfo.sol";

contract MarketLiquidationBotInfo is GetLiquidationMarketInfo {
    error MarketLiquidationBotInfoError(LiquidationMarketInfo[] output);

    constructor(address[] memory markets) {
        revert MarketLiquidationBotInfoError(getMarketsInfo(markets));
    }
}

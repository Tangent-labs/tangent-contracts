// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";

contract GetMarketLiquidation {
    struct MarketLiquidationInfo {
        address market;
        address collatToken;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 collateralUSDPrice;
        uint256 oracleDecimals;
    }

    function getMarketsLiquidationInfo(address[] memory markets) public view returns (MarketLiquidationInfo[] memory) {
        MarketLiquidationInfo[] memory marketRows = new MarketLiquidationInfo[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            marketRows[i] = getMarketDetails(markets[i]);
        }
        return marketRows;
    }

    function getMarketDetails(address market) private view returns (MarketLiquidationInfo memory) {
        ICollateral marketCollateral = ICollateral(market);
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        return
            MarketLiquidationInfo({
                market:market,
                collatToken: address(marketCollateral.collatToken()),
                maxLTV: marketCollateral.maxLTV(),
                liquidationThreshold: marketCollateral.liquidationThreshold(),
                collateralUSDPrice: priceOracle.latestAnswer(),
                oracleDecimals: priceOracle.decimals()
            });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Infos, IERC20Metadata} from "../ERC20Infos.sol";
import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../interfaces/internals/tgUSD/IRewards.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";

contract GetLiquidationMarketInfo is ERC20Infos {
    struct LiquidationMarketInfo {
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 collateralUSDPrice;
        uint256 oracleDecimals;
    }

    function getMarketsInfo(address[] memory markets) public view returns (LiquidationMarketInfo[] memory) {
        LiquidationMarketInfo[] memory marketRows = new LiquidationMarketInfo[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            marketRows[i] = getMarketDetails(markets[i]);
        }
        return marketRows;
    }

    function getMarketDetails(address market) private view returns (LiquidationMarketInfo memory) {
        ICollateral marketCollateral = ICollateral(market);
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        return
            LiquidationMarketInfo({
                maxLTV: marketCollateral.maxLTV(),
                liquidationThreshold: marketCollateral.liquidationThreshold(),
                collateralUSDPrice: priceOracle.latestAnswer(),
                oracleDecimals: priceOracle.decimals()
            });
    }
}

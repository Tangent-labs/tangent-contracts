// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";

contract MarketDetailsUI {
    struct MarketDetailsUIIn {
        address account;
        address market;
    }

    struct MarketDetailsUIOut {
        uint256 healthRatio;
        uint256 totalDebt;
        uint256 totalUSDValue;
        uint256 totalAmount;
        uint256 positionDebt;
        uint256 positionUSDValue;
        uint256 positionAmount;
        uint256 collateralUSDPrice;
        uint256 maxLTV;
        IPriceOracle priceOracle;
    }

    error MarketDetailsUIOutError(MarketDetailsUIOut[] output);

    constructor(MarketDetailsUIIn[] memory usersMarkets) {
        MarketDetailsUIOut[] memory output = new MarketDetailsUIOut[](usersMarkets.length);
        for (uint256 index; index < usersMarkets.length; index++) {
            address market = usersMarkets[index].market;
            address account = usersMarkets[index].account;

            ICollateral marketCollateral = ICollateral(market);
            IPriceOracle priceOracle = marketCollateral.collatOracle();
            IDebtIR marketDebt = IDebtIR(market);
            uint256 collateralUSDPrice = priceOracle.latestAnswer();
            uint256 totalCollateral = marketCollateral.totalCollateral();

            output[index] = MarketDetailsUIOut({
                healthRatio: marketCollateral.healthRatio(account),
                totalDebt: marketDebt.totalDebt(),
                totalUSDValue: (totalCollateral * collateralUSDPrice) / 10 ** 18,
                totalAmount: totalCollateral,
                positionDebt: marketDebt.positionDebt(account),
                positionUSDValue: marketCollateral.positionValue(account),
                positionAmount: marketCollateral.collateralBalances(account),
                collateralUSDPrice: collateralUSDPrice,
                maxLTV: marketCollateral.maxLTV(),
                priceOracle: priceOracle
            });
        }
        revert MarketDetailsUIOutError(output);
    }
}

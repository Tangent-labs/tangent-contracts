// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";

import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {BalancesAllowances} from "../../BalancesAllowances.sol";

contract MarketDetailsUI is ERC20Infos, BalancesAllowances {
    struct MarketDetailsUIIn {
        address account;
        address market;
    }

    struct MarketDetailsUIOut {
        address marketAddress;
        ERC20Infos.ERC20StaticInfos collateralToken;
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
        BalancesAllowances.OutputBalanceAllowances[] obas;
        ERC20Infos.ERC20StaticInfos[] rewardTokens;
    }

    error MarketDetailsUIOutError(MarketDetailsUIOut output);

    constructor(MarketDetailsUIIn memory userMarket) {
        address market = userMarket.market;
        address account = userMarket.account;

        ICollateral marketCollateral = ICollateral(market);
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        IDebtIR marketDebt = IDebtIR(market);
        uint256 collateralUSDPrice = priceOracle.latestAnswer();
        uint256 totalCollateral = marketCollateral.totalCollateral();
        IERC20Metadata collatToken = marketCollateral.collatToken();

        BalancesAllowances.InputBalancesAllowances[] memory ibas = new BalancesAllowances.InputBalancesAllowances[](1);
        address[] memory spenders = new address[](1);
        spenders[0] = market;
        ibas[0] = BalancesAllowances.InputBalancesAllowances({token: collatToken, spenders: spenders});

        revert MarketDetailsUIOutError(
            MarketDetailsUIOut({
                marketAddress: market,
                collateralToken: getERC20StaticInfos(collatToken),
                healthRatio: marketCollateral.healthRatio(account),
                totalDebt: marketDebt.totalDebt(),
                totalUSDValue: (totalCollateral * collateralUSDPrice) / 10 ** 18,
                totalAmount: totalCollateral,
                positionDebt: marketDebt.positionDebt(account),
                positionUSDValue: marketCollateral.positionValue(account),
                positionAmount: marketCollateral.collateralBalances(account),
                collateralUSDPrice: collateralUSDPrice,
                maxLTV: marketCollateral.maxLTV(),
                priceOracle: priceOracle,
                obas: getBalancesAllowances(account, ibas),
                rewardTokens: getERC20StaticInfos(IRewards(market).getRewardTokens())
            })
        );
    }
}

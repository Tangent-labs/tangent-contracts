// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BalancesAllowances, OutputBalanceAllowances, InputBalancesAllowances} from "../BalancesAllowances.sol";
import {ERC20Infos, IERC20Metadata, ERC20StaticInfos} from "../ERC20Infos.sol";

import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ISociabilization} from "../../interfaces/internals/tgUSD/ISociabilization.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";

contract GetMarketDetails is BalancesAllowances, ERC20Infos {
    struct CollateralInfos {
        ERC20StaticInfos collateralToken;
        uint256 totalCollateralUSDValue;
        uint256 totalCollateralAmount;
        uint256 collateralUSDPrice;
        uint256 positionCollateralAmount;
        uint256 positionCollateralUSDValue;
        IPriceOracle priceOracle;
    }

    struct DebtInfos {
        uint256 totalDebt;
        uint256 userDebt;
        uint256 healthRatio;
        uint256 currentBorrowRate;
        uint256 futureBorrowRate;
        uint256 currentRewardCut;
        uint256 futureRewardCut;
    }
    struct MarketConstants {
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 minimumLoan;
        uint256 liquidationThreshold;
    }
    struct Sociabilization {
        uint256 socFeePercentage;
        uint256 socFeePending;
    }
    struct MarketRow {
        address marketAddress;
        CollateralInfos collateralInfos;
        DebtInfos debtInfos;
        MarketConstants constants;
        Sociabilization sociabilization;
        OutputBalanceAllowances[] obas;
        ERC20StaticInfos[] rewardTokens;
    }

    function getMarketDetails(address account, address market) public returns (MarketRow memory) {
        return
            MarketRow({
                marketAddress: market,
                collateralInfos: _getCollateralInfos(account, market),
                debtInfos: _getDebtInfos(account, market),
                constants: _getMarketConstants(market),
                sociabilization: _getSociabilization(market),
                obas: _getBalancesAllowances(account, market),
                rewardTokens: _getRewardTokens(market)
            });
    }

    function _getCollateralInfos(address account, address market) internal view returns (CollateralInfos memory) {
        ICollateral marketCollateral = ICollateral(market);
        IERC20Metadata collatToken = marketCollateral.collatToken();
        uint256 totalCollateral = marketCollateral.totalCollateral();
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        uint256 collateralUSDPrice = priceOracle.latestAnswer();

        return
            CollateralInfos({
                collateralToken: getERC20StaticInfos(collatToken),
                totalCollateralUSDValue: (totalCollateral * collateralUSDPrice) / 10 ** 18,
                totalCollateralAmount: totalCollateral,
                collateralUSDPrice: collateralUSDPrice,
                positionCollateralAmount: marketCollateral.collateralBalances(account),
                positionCollateralUSDValue: marketCollateral.positionValue(account),
                priceOracle: priceOracle
            });
    }

    function _getDebtInfos(address account, address market) internal returns (DebtInfos memory) {
        ICollateral marketCollateral = ICollateral(market);
        IDebtIR marketDebt = IDebtIR(market);
        IIRCalculator irCalculator = IIRCalculator(marketDebt.irCalculator());
        (, uint216 ir) = irCalculator.irCheckpoints(market);
        IRewardAccumulator _rewardAccumulator = IRewardAccumulator(marketCollateral.rewardAccumulator());

        return
            DebtInfos({
                totalDebt: marketDebt.totalDebt(),
                userDebt: marketDebt.userDebt(account),
                healthRatio: marketCollateral.healthRatio(account),
                currentBorrowRate: ir,
                futureBorrowRate: irCalculator.computeIRForMarket(market),
                currentRewardCut: _rewardAccumulator.lastRewardCuts(market),
                futureRewardCut: _rewardAccumulator.computeRCForMarket(market)
            });
    }

    function _getMarketConstants(address market) internal view returns (MarketConstants memory) {
        ICollateral marketCollateral = ICollateral(market);
        IDebtIR marketDebt = IDebtIR(market);

        return
            MarketConstants({
                maxLTV: marketCollateral.maxLTV(),
                maxMarketDebt: marketDebt.maxMarketDebt(),
                minimumLoan: marketDebt.minimumLoan(),
                liquidationThreshold: marketCollateral.liquidationThreshold()
            });
    }

    function _getSociabilization(address market) internal view returns (Sociabilization memory) {
        Sociabilization memory soc;

        try ISociabilization(market).socFeePercentage() {
            ISociabilization sociabilization = ISociabilization(market);
            soc = Sociabilization({socFeePercentage: sociabilization.socFeePercentage(), socFeePending: sociabilization.socFeePending()});
        } catch {
            soc = Sociabilization({socFeePercentage: 0, socFeePending: 0});
        }

        return soc;
    }
    function _getBalancesAllowances(address account, address market) internal view returns (OutputBalanceAllowances[] memory) {
        IERC20Metadata collatToken = ICollateral(market).collatToken();

        address[] memory spenders = new address[](1);
        spenders[0] = market;

        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](1);
        ibas[0] = InputBalancesAllowances({token: collatToken, spenders: spenders});

        return getBalancesAllowances(account, ibas);
    }

    function _getRewardTokens(address market) internal view returns (ERC20StaticInfos[] memory) {
        return getERC20StaticInfos(ICollateral(market).rewardAccumulator().getRewardTokens(market));
    }
}

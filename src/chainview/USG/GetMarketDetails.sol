// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BalancesAllowances, OutputBalanceAllowances, InputBalancesAllowances} from "../BalancesAllowances.sol";
import {ERC20Infos, IERC20Metadata, ERC20StaticInfos, IERC20} from "../ERC20Infos.sol";

import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";
import {IMarketViewer} from "../../interfaces/internals/USG/IMarketViewer.sol";
import {IDebtIR} from "../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator, IRParams} from "../../interfaces/internals/USG/IIRCalculator.sol";
import {IPriceOracle} from "../../interfaces/internals/USG/IPriceOracle.sol";
import {IRewardAccumulator, RCParams, Reward} from "../../interfaces/internals/USG/IRewardAccumulator.sol";

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
        address receipt;
        IRParams irParams;
        RCParams rcParams;
        PauseStruct pauseStruct;
    }

    struct PauseStruct {
        bool isDepositPaused;
        bool isBorrowPaused;
        bool isLeveragePaused;
    }

    struct MarketRewards {
        ERC20StaticInfos erc20Info;
        Reward streamingData;
    }
    struct MarketRow {
        address marketAddress;
        CollateralInfos collateralInfos;
        DebtInfos debtInfos;
        MarketConstants constants;
        OutputBalanceAllowances[] obas;
        MarketRewards[] rewardData;
    }

    function getMarketDetails(address account, address market, IMarketViewer marketViewer) public returns (MarketRow memory) {
        return
            MarketRow({
                marketAddress: market,
                collateralInfos: _getCollateralInfos(account, market, marketViewer),
                debtInfos: _getDebtInfos(account, market, marketViewer),
                constants: _getMarketConstants(market),
                obas: _getBalancesAllowances(account, market),
                rewardData: _getRewardData(market)
            });
    }

    function _getCollateralInfos(address account, address market, IMarketViewer marketViewer) internal view returns (CollateralInfos memory) {
        ICollateral marketCollateral = ICollateral(market);
        IERC20Metadata collatToken = marketCollateral.collatToken();
        uint256 totalCollateral = marketCollateral.totalCollateral();
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        uint256 collateralUSDPrice = priceOracle.latestAnswer(true);

        return
            CollateralInfos({
                collateralToken: getERC20StaticInfos(collatToken),
                totalCollateralUSDValue: (totalCollateral * collateralUSDPrice) / 10 ** 18,
                totalCollateralAmount: totalCollateral,
                collateralUSDPrice: collateralUSDPrice,
                positionCollateralAmount: marketCollateral.collateralBalances(account),
                positionCollateralUSDValue: marketViewer.positionValue(marketCollateral, account),
                priceOracle: priceOracle
            });
    }

    function _getDebtInfos(address account, address market, IMarketViewer marketViewer) internal returns (DebtInfos memory) {
        ICollateral marketCollateral = ICollateral(market);
        IDebtIR marketDebt = IDebtIR(market);
        IIRCalculator irCalculator = IIRCalculator(marketDebt.irCalculator());
        IRewardAccumulator _rewardAccumulator = IRewardAccumulator(marketCollateral.rewardAccumulator());

        return
            DebtInfos({
                totalDebt: marketViewer.totalDebt(marketDebt),
                userDebt: marketViewer.userDebt(marketDebt, account),
                healthRatio: marketViewer.healthRatio(market, account),
                currentBorrowRate: irCalculator.getIRCheckpoint(market).ir,
                futureBorrowRate: irCalculator.computeIRForMarket(market),
                currentRewardCut: _rewardAccumulator.lastRewardCuts(market),
                futureRewardCut: _rewardAccumulator.computeRCForMarket(market)
            });
    }

    function _getReceiptToken(address market) internal view returns (address) {
        (bool ok, bytes memory data) = market.staticcall(abi.encodePacked(bytes4(keccak256("receipt()"))));
        if (ok) {
            return abi.decode(data, (address));
        }
        return address(0);
    }

    function _getPauseStruct(address market) internal view returns (PauseStruct memory) {
        (uint64 isDepositPaused, uint64 isBorrowPaused, uint64 isLeveragePaused) = IPauseSettings(market).getPausedSettings();

        return
            PauseStruct({
                isDepositPaused: isDepositPaused != 0 ? true : false,
                isBorrowPaused: isBorrowPaused != 0 ? true : false,
                isLeveragePaused: isLeveragePaused != 0 ? true : false
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
                liquidationThreshold: marketCollateral.liquidationThreshold(),
                receipt: _getReceiptToken(market),
                irParams: _getIRParams(market),
                rcParams: _getRCParams(market),
                pauseStruct: _getPauseStruct(market)
            });
    }

    function _getBalancesAllowances(address account, address market) internal view returns (OutputBalanceAllowances[] memory) {
        IERC20Metadata collatToken = ICollateral(market).collatToken();

        address[] memory spenders = new address[](1);
        spenders[0] = market;

        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](1);
        ibas[0] = InputBalancesAllowances({token: collatToken, spenders: spenders});

        return getBalancesAllowances(account, ibas);
    }

    function _getRewardData(address market) internal view returns (MarketRewards[] memory) {
        IRewardAccumulator _rewardAccumulator = ICollateral(market).rewardAccumulator();
        IERC20[] memory rewardTokens = _rewardAccumulator.getRewardTokens(market);

        MarketRewards[] memory mRewards = new MarketRewards[](rewardTokens.length);

        for (uint256 i; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            mRewards[i] = MarketRewards({erc20Info: getERC20StaticInfos(token), streamingData: _rewardAccumulator.getRewardData(market, token)});
        }

        return mRewards;
    }

    function _getIRParams(address market) internal view returns (IRParams memory) {
        return IDebtIR(market).irCalculator().getIRParams(address(market));
    }

    function _getRCParams(address market) internal view returns (RCParams memory) {
        return ICollateral(market).rewardAccumulator().getRCParams(address(market));
    }
}

interface IPauseSettings {
    function getPausedSettings() external view returns (uint64, uint64, uint64);
}

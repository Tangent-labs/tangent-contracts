// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {ERC20Infos, IERC20Metadata} from "../ERC20Infos.sol";

import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../interfaces/internals/tgUSD/IRewards.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ISociabilization} from "../../interfaces/internals/tgUSD/ISociabilization.sol";

contract GetMarketDetails is BalancesAllowances, ERC20Infos {
    struct CollateralInfos {
        ERC20Infos.ERC20StaticInfos collateralToken;
        uint256 totalCollateralUSDValue;
        uint256 totalCollateralAmount;
        uint256 collateralUSDPrice;
        uint256 positionCollateralAmount;
        uint256 positionCollateralUSDValue;
        IPriceOracle priceOracle;
    }

    struct DebtInfos {
        uint256 totalDebt;
        uint256 positionDebt;
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
        BalancesAllowances.OutputBalanceAllowances[] obas;
        ERC20Infos.ERC20StaticInfos[] rewardTokens;
    }

    function getMarketDetails(address account, address market) public returns (MarketRow memory) {
        ICollateral marketCollateral = ICollateral(market);
        IPriceOracle priceOracle = marketCollateral.collatOracle();
        IDebtIR marketDebt = IDebtIR(market);
        uint256 collateralUSDPrice = priceOracle.latestAnswer();
        uint256 totalCollateral = marketCollateral.totalCollateral();
        IERC20Metadata collatToken = marketCollateral.collatToken();

        address[] memory spenders = new address[](1);
        spenders[0] = market;

        BalancesAllowances.InputBalancesAllowances[] memory ibas = new BalancesAllowances.InputBalancesAllowances[](1);
        ibas[0] = BalancesAllowances.InputBalancesAllowances({token: collatToken, spenders: spenders});

        IIRCalculator irCalculator = IIRCalculator(marketDebt.irCalculator());

        address _account = account;
        address _market = market;

        Sociabilization memory soc;

        try ISociabilization(_market).socFeePercentage() {
            ISociabilization sociabilization = ISociabilization(_market);
            soc = Sociabilization({socFeePercentage: sociabilization.socFeePercentage(), socFeePending: sociabilization.socFeePending()});
        } catch {
            soc = Sociabilization({socFeePercentage: 0, socFeePending: 0});
        }

        return
            MarketRow({
                marketAddress: _market,
                collateralInfos: CollateralInfos({
                    collateralToken: getERC20StaticInfos(collatToken),
                    totalCollateralUSDValue: (totalCollateral * collateralUSDPrice) / 10 ** 18,
                    totalCollateralAmount: totalCollateral,
                    collateralUSDPrice: collateralUSDPrice,
                    positionCollateralAmount: marketCollateral.collateralBalances(_account),
                    positionCollateralUSDValue: marketCollateral.positionValue(_account),
                    priceOracle: priceOracle
                }),
                debtInfos: DebtInfos({
                    totalDebt: marketDebt.totalDebt(),
                    positionDebt: marketDebt.positionDebt(_account),
                    healthRatio: marketCollateral.healthRatio(_account),
                    currentBorrowRate: marketDebt.lastIR(),
                    futureBorrowRate: irCalculator.computeIRForMarket(_market),
                    currentRewardCut: IRewards(_market).rewardCutPercentage(),
                    futureRewardCut: irCalculator.computeRCForMarket(_market)
                }),
                constants: MarketConstants({
                    maxLTV: marketCollateral.maxLTV(),
                    maxMarketDebt: marketDebt.maxMarketDebt(),
                    minimumLoan: marketDebt.minimumLoan(),
                    liquidationThreshold: marketCollateral.liquidationThreshold()
                }),
                sociabilization: soc,
                obas: getBalancesAllowances(_account, ibas),
                rewardTokens: getERC20StaticInfos(IRewards(_market).getRewardTokens())
            });
    }
}

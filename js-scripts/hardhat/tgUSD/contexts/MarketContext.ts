import {ethers} from "hardhat";
import {ContractTransactionReceipt, Interface, InterfaceAbi, LogDescription, MaxUint256} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN} from "../config/market";

import * as MarketCreator from "../../../../artifacts/src/tgUSD/Utilities/MarketCreator.sol/MarketCreator.json";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;

export class MarketContext {
    convexCrvMarkets: {[key: string]: ConvexCrvLPMarket} = {};
    convexFxnMarkets: {[key: string]: ConvexFxnLPMarket} = {};

    async deployConvexCrvMarkets(keys: ConvexCrvMarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key];

            const receipt = await (
                await baseContext.marketCreator.connect(baseContext.owner).createConvexCrvMarket(
                    {
                        collatToken: staticConfig.collatToken,
                        collatOracle: oracleContext.oracles[staticConfig.collatName],
                        maxLTV: staticConfig.maxLTV,
                        maxMarketDebt: staticConfig.maxMarketDebt,
                        liquidationThreshold: staticConfig.liquidationThreshold,
                        minimumLoan: staticConfig.minimumLoan,
                        _rewardTokens: staticConfig.rewards,
                    },
                    staticConfig.cvxRewardToken,
                    staticConfig.pid,
                    1_000,
                    {
                        rMin: 4_000,
                        rMax: 400_000,
                        pMin: 980_000,
                        pMax: 1_000_000,
                        pInf: 997_500,
                        a1: 2,
                        a2: 2,
                        k: 250,
                    },
                    {
                        startCutPercentage: 50_000,
                        endCutPercentage: 100_000,
                        stepAmount: 4,
                        startCutPrice: 995000000000000000n,
                        endCutPrice: 900000000000000000n,
                    }
                )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async deployConvexFxnMarkets(keys: ConvexFxnMarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CONVEX_FXN[key];

            const receipt = await (
                await baseContext.marketCreator.connect(baseContext.owner).createConvexFxnMarket(
                    {
                        collatToken: staticConfig.collatToken,
                        collatOracle: oracleContext.oracles[staticConfig.collatName],
                        maxLTV: staticConfig.maxLTV,
                        maxMarketDebt: staticConfig.maxMarketDebt,
                        liquidationThreshold: staticConfig.liquidationThreshold,
                        minimumLoan: staticConfig.minimumLoan,
                        _rewardTokens: staticConfig.rewards,
                    },
                    staticConfig.pid,
                    1_000,
                    {
                        rMin: 4_000,
                        rMax: 400_000,
                        pMin: 980_000,
                        pMax: 995_000,
                        pInf: 0,
                        a1: 2,
                        a2: 2,
                        k: 0,
                    },
                    {
                        startCutPercentage: 50_000,
                        endCutPercentage: 100_000,
                        stepAmount: 4,
                        startCutPrice: 995000000000000000n,
                        endCutPrice: 900000000000000000n,
                    }
                )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async parseCreateMarketLogs(key: string, receipt: ContractTransactionReceipt) {
        const iface = new Interface(MarketCreator.abi);

        for (let index = 0; index < receipt!.logs.length; index++) {
            const log = receipt!.logs[index];
            const parsedLog = iface.parseLog(log)!;

            if (STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys]) {
                await this.getConvexCrvMarket(key as ConvexCrvMarketKeys, parsedLog);
            } else if (STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys]) {
                await this.getConvexFxnMarket(key as ConvexFxnMarketKeys, parsedLog);
            }
        }
    }

    async getConvexCrvMarket(key: ConvexCrvMarketKeys, parsedLog: LogDescription) {
        if (parsedLog?.name && parsedLog.name === "MarketConvexCrvCreated") {
            const market = await ethers.getContractAt("ConvexCrvLPMarket", parsedLog.args.proxy);
            this.convexCrvMarkets[key] = market;
        }
    }

    async getConvexFxnMarket(key: ConvexFxnMarketKeys, parsedLog: LogDescription) {
        if (parsedLog?.name && parsedLog.name === "MarketConvexFxnCreated") {
            const market = await ethers.getContractAt("ConvexFxnLPMarket", parsedLog.args.proxy);
            this.convexFxnMarkets[key] = market;
        }
    }
}

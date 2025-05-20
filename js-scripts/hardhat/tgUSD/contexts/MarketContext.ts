import {ethers} from "hardhat";
import {AddressLike, ContractTransactionReceipt, Interface, InterfaceAbi, LogDescription, MaxUint256} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket, MarketNoSociabilization} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {
    HEC_CONFIG_IR_PARAMS,
    HEC_CONFIG_RC_PARAMS,
    LEC_CONFIG_IR_PARAMS,
    LEC_CONFIG_RC_PARAMS,
    STATIC_CONFIG_CONVEX_CURVE,
    STATIC_CONFIG_CONVEX_FXN,
    STATIC_CONFIG_PT_PENDLE,
} from "../config/market";

import * as MarketCreator from "../../../../artifacts/src/tgUSD/Utilities/MarketCreator.sol/MarketCreator.json";
import {MarketInitStruct} from "../../../../typechain-types/src/tgUSD/Market/MarketNoSociabilization";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;
export type PendlePTMarketsKeys = keyof typeof STATIC_CONFIG_PT_PENDLE;

export class MarketContext {
    convexCrvMarkets: {[key: string]: ConvexCrvLPMarket} = {};
    convexFxnMarkets: {[key: string]: ConvexFxnLPMarket} = {};
    pendlePTMarkets: {[key: string]: MarketNoSociabilization} = {};

    marketInit(staticConfig: any, oracle: AddressLike): MarketInitStruct {
        return {
            collatToken: staticConfig.collatToken,
            collatOracle: oracle,
            maxLTV: staticConfig.maxLTV,
            maxMarketDebt: staticConfig.maxMarketDebt,
            liquidationThreshold: staticConfig.liquidationThreshold,
            liquidationFee: 1_000,
            minimumLoan: staticConfig.minimumLoan,
        };
    }

    async deployConvexCrvMarkets(keys: ConvexCrvMarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createConvexCrvMarket(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName]),
                        staticConfig.cvxRewardToken,
                        staticConfig.pid,
                        1_000,
                        HEC_CONFIG_IR_PARAMS,
                        HEC_CONFIG_RC_PARAMS
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
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createConvexFxnMarket(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName]),
                        staticConfig.pid,
                        1_000,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS
                    )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async deployPendlePTMarkets(keys: PendlePTMarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_PT_PENDLE[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createNoSociabilizationMarket(this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName]), LEC_CONFIG_IR_PARAMS, LEC_CONFIG_RC_PARAMS)
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
                this.convexCrvMarkets[key] = (await this.getConvexCrvMarket(parsedLog))!;
            } else if (STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys]) {
                this.convexFxnMarkets[key] = (await this.getConvexFxnMarket(parsedLog))!;
            } else if (STATIC_CONFIG_PT_PENDLE[key as PendlePTMarketsKeys]) {
                this.pendlePTMarkets[key] = (await this.getNoSocMarket(parsedLog))!;
            }
        }
    }

    async getConvexCrvMarket(parsedLog: LogDescription) {
        if (parsedLog?.name && parsedLog.name === "MarketConvexCrvCreated") {
            const market = await ethers.getContractAt("ConvexCrvLPMarket", parsedLog.args.proxy);
            return market;
        }
    }

    async getConvexFxnMarket(parsedLog: LogDescription) {
        if (parsedLog?.name && parsedLog.name === "MarketConvexFxnCreated") {
            const market = await ethers.getContractAt("ConvexFxnLPMarket", parsedLog.args.proxy);
            return market;
        }
    }

    async getNoSocMarket(parsedLog: LogDescription) {
        if (parsedLog?.name && parsedLog.name === "MarketNoSociabilizationCreated") {
            const market = await ethers.getContractAt("MarketNoSociabilization", parsedLog.args.proxy);
            return market;
        }
    }
}

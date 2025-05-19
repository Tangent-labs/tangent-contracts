import {ethers} from "hardhat";
import {AddressLike, ContractTransactionReceipt, Interface, InterfaceAbi, LogDescription, MaxUint256} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {HEC_CONFIG_IR_PARAMS, HEC_CONFIG_RC_PARAMS, LEC_CONFIG_IR_PARAMS, LEC_CONFIG_RC_PARAMS, STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN} from "../config/market";

import * as MarketCreator from "../../../../artifacts/src/tgUSD/Utilities/MarketCreator.sol/MarketCreator.json";
import {MarketInitStruct} from "../../../../typechain-types/src/tgUSD/Market/MarketNoSociabilization";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;

export class MarketContext {
    convexCrvMarkets: {[key: string]: ConvexCrvLPMarket} = {};
    convexFxnMarkets: {[key: string]: ConvexFxnLPMarket} = {};

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

import {ethers} from "hardhat";
import {AddressLike, ContractTransactionReceipt, Interface, InterfaceAbi, LogDescription, MaxUint256} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket, BasicERC20Market} from "../../../../typechain-types";
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

import * as MarketCreator from "../../../../artifacts/src/USG/Utilities/MarketCreator.sol/MarketCreator.json";
import {MarketInitStruct} from "../../../../typechain-types/src/USG/Market/BasicERC20Market";
import {commonERC20} from "@tangent/defi-resources";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;
export type PendlePTMarketsKeys = keyof typeof STATIC_CONFIG_PT_PENDLE;

export class MarketContext {
    convexCrvMarkets: {[key: string]: ConvexCrvLPMarket} = {};
    convexFxnMarkets: {[key: string]: ConvexFxnLPMarket} = {};
    pendlePTMarkets: {[key: string]: BasicERC20Market} = {};

    marketInit(staticConfig: any, oracle: AddressLike, name: string): MarketInitStruct {
        return {
            collatToken: staticConfig.collatToken,
            collatOracle: oracle,
            maxLTV: staticConfig.maxLTV,
            maxMarketDebt: staticConfig.maxMarketDebt,
            liquidationThreshold: staticConfig.liquidationThreshold,
            liquidationFee: 1_000,
            minimumLoan: staticConfig.minimumLoan,
            name: name,
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
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], "Convex CRV - " + staticConfig.collatName),
                        staticConfig.cvxRewardToken,
                        staticConfig.pid,
                        HEC_CONFIG_IR_PARAMS,
                        HEC_CONFIG_RC_PARAMS
                    )
            ).wait();

            const market = await this.parseCreateMarketLogs(key, receipt!);
            await baseContext.rewardAccumulator.connect(baseContext.owner).addNewRewards(market, [commonERC20.CRV, commonERC20.CVX]);
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
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], "Convex FXN - " + staticConfig.collatName),
                        staticConfig.pid,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS
                    )
            ).wait();
            const market = await this.parseCreateMarketLogs(key, receipt!);
            await baseContext.rewardAccumulator.connect(baseContext.owner).addNewRewards(market, [commonERC20.CRV, commonERC20.FXN, commonERC20.CVX]);
        }
    }

    async deployPendlePTMarkets(keys: PendlePTMarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_PT_PENDLE[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createBasicERC20Market(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], "PENDLE PT - " + staticConfig.collatName),
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS
                    )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async parseCreateMarketLogs(key: string, receipt: ContractTransactionReceipt) {
        const iface = new Interface(MarketCreator.abi);

        let marketAddress = "";
        for (let index = 0; index < receipt!.logs.length; index++) {
            const log = receipt!.logs[index];
            const parsedLog = iface.parseLog(log)!;
            if (parsedLog?.name && ["MarketConvexCrvCreated", "MarketConvexFxnCreated", "BasicERC20MarketCreated"].includes(parsedLog.name)) {
                if (STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys]) {
                    const market = await this.getConvexCrvMarket(parsedLog);
                    this.convexCrvMarkets[key] = market;
                    marketAddress = await market.getAddress();
                } else if (STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys]) {
                    const market = await this.getConvexFxnMarket(parsedLog);
                    this.convexFxnMarkets[key] = market;
                    marketAddress = await market.getAddress();
                } else if (STATIC_CONFIG_PT_PENDLE[key as PendlePTMarketsKeys]) {
                    const market = await this.getBasicERC20Market(parsedLog);
                    this.pendlePTMarkets[key] = market;
                    marketAddress = await market.getAddress();
                }
            }
        }
        return marketAddress;
    }

    async getConvexCrvMarket(parsedLog: LogDescription) {
        return await ethers.getContractAt("ConvexCrvLPMarket", parsedLog.args.proxy);
    }

    async getConvexFxnMarket(parsedLog: LogDescription) {
        return await ethers.getContractAt("ConvexFxnLPMarket", parsedLog.args.proxy);
    }

    async getBasicERC20Market(parsedLog: LogDescription) {
        return await ethers.getContractAt("BasicERC20Market", parsedLog.args.proxy);
    }
}

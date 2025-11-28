import { ethers } from "hardhat";
import { AddressLike, ContractTransactionReceipt, Interface } from "ethers";
import { ConvexCrvLPMarket, ConvexFxnLPMarket, BasicERC20Market, CurveGaugeMarket, StakeDaoVaultV2Market } from "../../../../typechain-types";

import { commonERC20 } from "@tangent/defi-resources";

import { BaseContext } from "./BaseContext";
import { OracleContext } from "./OracleContext";
import {
    HEC_CONFIG_IR_PARAMS,
    HEC_CONFIG_RC_PARAMS,
    LEC_CONFIG_IR_PARAMS,
    LEC_CONFIG_RC_PARAMS,
    STATIC_CONFIG_CONVEX_CURVE,
    STATIC_CONFIG_CONVEX_FXN,
    STATIC_CONFIG_BASIC_ERC20s,
    STATIC_CONFIG_CURVE_GAUGE,
    STATIC_CONFIG_STAKEDAO_VAULT_V2,
} from "../config/market";

import * as MarketCreator from "../../../../artifacts/src/USG/Utilities/MarketCreator.sol/MarketCreator.json";
import { MarketInitStruct } from "../../../../typechain-types/src/USG/Market/BasicERC20Market";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;
export type PendlePTMarketsKeys = keyof typeof STATIC_CONFIG_BASIC_ERC20s;
export type CurveGaugeMarketsKeys = keyof typeof STATIC_CONFIG_CURVE_GAUGE;
export type StakeDaoVaultV2MarketsKeys = keyof typeof STATIC_CONFIG_STAKEDAO_VAULT_V2;

export class MarketContext {
    convexCrvMarkets: { [key: string]: ConvexCrvLPMarket } = {};
    convexFxnMarkets: { [key: string]: ConvexFxnLPMarket } = {};
    stakeDaoVaultMarkets: { [key: string]: StakeDaoVaultV2Market } = {};
    curveGaugeMarkets: { [key: string]: CurveGaugeMarket } = {};
    basicERC20Markets: { [key: string]: BasicERC20Market } = {};


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

    async deployCurveGaugeMarkets(keys: CurveGaugeMarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CURVE_GAUGE[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createCurveGaugeMarket(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], key),
                        staticConfig.gaugeToken,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS,
                    )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async deployStakeDaoVaultV2Markets(keys: StakeDaoVaultV2MarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_STAKEDAO_VAULT_V2[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createStakeDaoVaultV2Market(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], key),
                        staticConfig.vaultToken,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS,
                    )
            ).wait();

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async deployBasicERC20Markets(keys: PendlePTMarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_BASIC_ERC20s[key];

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createBasicERC20Market(
                        this.marketInit(staticConfig, oracleContext.oracles[staticConfig.collatName], key),
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
            let parsedLog = iface.parseLog(log);

            if (parsedLog?.name && ["MarketConvexCrvCreated", "MarketConvexFxnCreated", "BasicERC20MarketCreated", "MarketCurveGauge", "MarketStakeDaoVaultV2"].includes(parsedLog.name)) {
                marketAddress = parsedLog.args.proxy as string
                if (STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys]) {
                    this.convexCrvMarkets[key] = await ethers.getContractAt("ConvexCrvLPMarket", marketAddress);
                } else if (STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys]) {
                    this.convexFxnMarkets[key] = await ethers.getContractAt("ConvexFxnLPMarket", marketAddress);
                } else if (STATIC_CONFIG_BASIC_ERC20s[key as PendlePTMarketsKeys]) {
                    this.basicERC20Markets[key] = await ethers.getContractAt("BasicERC20Market", marketAddress);
                } else if (STATIC_CONFIG_CURVE_GAUGE[key as CurveGaugeMarketsKeys]) {
                    this.curveGaugeMarkets[key] = await ethers.getContractAt("CurveGaugeMarket", marketAddress);
                }
            }
        }
        return marketAddress;
    }



}

import { ethers } from "hardhat";
import { AddressLike, ContractTransactionReceipt, Interface, MaxUint256, Signer } from "ethers";
import { ConvexCrvLPMarket, ConvexFxnLPMarket, BasicERC20Market, CurveGaugeMarket, StakeDaoVaultV2Market } from "../../../../typechain-types";
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
import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;
export type BasicERC20MarketKeys = keyof typeof STATIC_CONFIG_BASIC_ERC20s;
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
            liquidationFee: 50_000,
            minimumLoan: staticConfig.minimumLoan,
            rewardTokens: staticConfig.rewardTokens,
            name: name,
        };
    }

    async deployConvexCrvMarkets(keys: ConvexCrvMarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key];
            if (!staticConfig) {
                throw Error(`No static config for ${key} market`)
            }
            const oracle = oracleContext.oracles[staticConfig.collatName]
            if (!oracle) {
                throw Error(`No oracle deployed with key ${staticConfig.collatName} for ${key}`)
            }
            await impersonateAccount(await baseContext.owner.getAddress())
            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createConvexCrvMarket(
                        this.marketInit(staticConfig, oracle, "Convex CRV - " + staticConfig.collatName),
                        staticConfig.pid,
                        HEC_CONFIG_IR_PARAMS,
                        HEC_CONFIG_RC_PARAMS
                    )
            ).wait();

            await stopImpersonatingAccount(await baseContext.owner.getAddress())
            await this.parseCreateMarketLogs(key, receipt!);

        }
    }

    async deployConvexFxnMarkets(keys: ConvexFxnMarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CONVEX_FXN[key];
            if (!staticConfig) {
                throw Error(`No static config for ${key} market`)
            }
            const oracle = oracleContext.oracles[staticConfig.collatName]
            if (!oracle) {
                throw Error(`No oracle deployed with key ${staticConfig.collatName} for ${key}`)
            }
            await impersonateAccount(await baseContext.owner.getAddress())

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createConvexFxnMarket(
                        this.marketInit(staticConfig, oracle, "Convex FXN - " + staticConfig.collatName),
                        staticConfig.pid,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS
                    )
            ).wait();
            await stopImpersonatingAccount(await baseContext.owner.getAddress())

            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async deployCurveGaugeMarkets(keys: CurveGaugeMarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext, users: Signer[]) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_CURVE_GAUGE[key];
            if (!staticConfig) {
                throw Error(`No static config for ${key} market`)
            }
            const oracle = oracleContext.oracles[staticConfig.collatName]
            if (!oracle) {
                throw Error(`No oracle deployed with key ${staticConfig.collatName} for ${key}`)
            }

            await impersonateAccount(await baseContext.owner.getAddress())

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createCurveGaugeMarket(
                        this.marketInit(staticConfig, oracle, `Curve Gauge - ${key}`),
                        staticConfig.gaugeToken,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS,
                    )
            ).wait();
            await stopImpersonatingAccount(await baseContext.owner.getAddress())

            await this.parseCreateMarketLogs(key, receipt!);

            const market = this.curveGaugeMarkets[key]
            const gauge = await ethers.getContractAt("IGauge", await market.receiptToken())
            const collat = await ethers.getContractAt("IERC20", staticConfig.collatToken)
            for (let index = 0; index < 4; index++) {
                const user = users[index];
                await impersonateAccount(await user.getAddress())

                await collat.connect(user).approve(gauge, MaxUint256);
                await gauge.connect(user)["deposit(uint256)"](await collat.balanceOf(user) / 2n)
                await stopImpersonatingAccount(await user.getAddress())

            }
        }
    }

    async deployStakeDaoVaultV2Markets(keys: StakeDaoVaultV2MarketsKeys[], baseContext: BaseContext, oracleContext: OracleContext, users: Signer[]) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_STAKEDAO_VAULT_V2[key];
            if (!staticConfig) {
                throw Error(`No static config for ${key} market`)
            }
            const oracle = oracleContext.oracles[staticConfig.collatName]
            if (!oracle) {
                throw Error(`No oracle deployed with key ${staticConfig.collatName} for ${key}`)
            }
            await impersonateAccount(await baseContext.owner.getAddress())

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createStakeDaoVaultV2Market(
                        this.marketInit(staticConfig, oracle, `StakeDao Vault - ${key}`),
                        staticConfig.vaultToken,
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS,
                    )
            ).wait();
            await stopImpersonatingAccount(await baseContext.owner.getAddress())


            await this.parseCreateMarketLogs(key, receipt!);


            const market = this.stakeDaoVaultMarkets[key]
            const vault = await ethers.getContractAt("IStakeDaoVaultV2", await market.receiptToken())
            const collat = await ethers.getContractAt("IERC20", staticConfig.collatToken)
            for (let index = 0; index < 3; index++) {
                const user = users[index];

                await impersonateAccount(await user.getAddress())

                await collat.connect(user).approve(vault, MaxUint256);
                await vault.connect(user)["deposit(uint256,address)"](await collat.balanceOf(user) / 2n, user)

                await stopImpersonatingAccount(await user.getAddress())

            }
        }
    }

    async deployBasicERC20Markets(keys: BasicERC20MarketKeys[], baseContext: BaseContext, oracleContext: OracleContext) {
        for (let index = 0; index < keys.length; index++) {
            const key = keys[index];
            const staticConfig = STATIC_CONFIG_BASIC_ERC20s[key];
            if (!staticConfig) {
               continue;
                // throw Error(`No static config for ${key} market`)
            }
            const oracle = oracleContext.oracles[staticConfig.collatName]
            if (!oracle) {
                throw Error(`No oracle deployed with key ${staticConfig.collatName} for ${key}`)
            }
            await impersonateAccount(await baseContext.owner.getAddress())

            const receipt = await (
                await baseContext.marketCreator
                    .connect(baseContext.owner)
                    .createBasicERC20Market(
                        this.marketInit(staticConfig, oracle, key),
                        LEC_CONFIG_IR_PARAMS,
                        LEC_CONFIG_RC_PARAMS
                    )
            ).wait();
            await stopImpersonatingAccount(await baseContext.owner.getAddress())


            await this.parseCreateMarketLogs(key, receipt!);
        }
    }

    async parseCreateMarketLogs(key: string, receipt: ContractTransactionReceipt) {
        const iface = new Interface(MarketCreator.abi);

        let marketAddress = "";
        for (let index = 0; index < receipt!.logs.length; index++) {
            const log = receipt!.logs[index];
            let parsedLog = iface.parseLog(log);

            if (parsedLog && ["MarketConvexCrvCreated", "MarketConvexFxnCreated", "BasicERC20MarketCreated", "MarketCurveGaugeCreated", "MarketStakeDaoVaultV2Created"].includes(parsedLog.name)) {
                marketAddress = parsedLog.args.proxy as string
                switch (parsedLog.name) {
                    case "MarketConvexCrvCreated":
                        this.convexCrvMarkets[key] = await ethers.getContractAt("ConvexCrvLPMarket", marketAddress);
                        break;
                    case "MarketConvexFxnCreated":
                        this.convexFxnMarkets[key] = await ethers.getContractAt("ConvexFxnLPMarket", marketAddress);
                        break;
                    case "BasicERC20MarketCreated":
                        this.basicERC20Markets[key] = await ethers.getContractAt("BasicERC20Market", marketAddress);
                        break;
                    case "MarketCurveGaugeCreated":
                        this.curveGaugeMarkets[key] = await ethers.getContractAt("CurveGaugeMarket", marketAddress);
                        break;
                    case "MarketStakeDaoVaultV2Created":
                        this.stakeDaoVaultMarkets[key] = await ethers.getContractAt("StakeDaoVaultV2Market", marketAddress);
                        break;

                }
            }
        }
        return marketAddress;
    }
}

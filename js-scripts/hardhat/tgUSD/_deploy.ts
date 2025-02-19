import {BaseContext} from "./contexts/BaseContext";
import {OracleContext} from "./contexts/OracleContext";
import {ConvexCrvMarketKeys, ConvexFxnMarketKeys, MarketContext} from "./contexts/MarketContext";
import * as fs from "fs";

import {STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN} from "./config/market";
import {deploytgUsd} from "./actions/deploytgUsd";
import {LpDeployContext} from "./contexts/LPDeployContext";
import {WStablesContext} from "./contexts/WStableContext";

async function main() {
    const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deploytgUsd();

    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext)));
    console.info("\x1b[32m%s\x1b[0m", "Contracts deployed and setup !");
}

type Market = {
    marketAddress: string;
    collatName: string;
    collatAddress: string;
    marketType: string;
};

async function createJSONAddress(
    baseContext: BaseContext,
    marketContext: MarketContext,
    oracleContext: OracleContext,
    lpDeployContext: LpDeployContext,
    wStableContext: WStablesContext
) {
    const markets: Market[] = [];
    for (const key in marketContext.convexCrvMarkets) {
        const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys];
        const market = await marketContext.convexCrvMarkets[key].getAddress();

        markets.push({
            marketAddress: market,
            collatName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_CRV",
        });
    }
    for (const key in marketContext.convexFxnMarkets) {
        const market = await marketContext.convexFxnMarkets[key].getAddress();
        const staticConfig = STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys];

        markets.push({
            marketAddress: market,
            collatName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_FXN",
        });
    }

    let oracles: {[key: string]: string} = {};
    for (const prop in oracleContext.oracles) {
        const oracle = await oracleContext.oracles[prop].getAddress();
        oracles[prop] = oracle;
    }

    const lps: {[key: string]: string} = {};
    for (const prop in lpDeployContext.stableLp) {
        const lp = await lpDeployContext.stableLp[prop].getAddress();
        lps[prop] = lp;
    }

    const wStables: {[key: string]: string} = {};
    for (const prop in wStableContext.wStable) {
        const wStable = await wStableContext.wStable[prop].getAddress();
        wStables[prop] = wStable;
    }

    oracles["tgUSD"] = await oracleContext.tgUSDOracle.getAddress();
    return {
        utilities: {
            controlTower: await baseContext.controlTower.getAddress(),
            rewardAccumulator: await baseContext.rewardAccumulator.getAddress(),
            zapper: await baseContext.zapper.getAddress(),
            marketCreator: await baseContext.marketCreator.getAddress(),
        },
        tokens: {
            tgUSD: await baseContext.tgUSD.getAddress(),
            sgUSD: await baseContext.sgUSD.getAddress(),
        },
        markets,
        oracles,
        lps,
        wStables,
    };
}

main();

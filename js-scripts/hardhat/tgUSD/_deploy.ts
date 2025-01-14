import {BaseContext} from "./contexts/BaseContext";
import {OracleContext} from "./contexts/OracleContext";
import {ConvexCrvMarketKeys, ConvexFxnMarketKeys, MarketContext} from "./contexts/MarketContext";
import * as fs from "fs";
import {curveLp} from "convergence-defi-tools";
import {parseEther, parseUnits} from "ethers";
import {STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN} from "./config/market";
async function main() {
    const baseContext = new BaseContext();
    const oracleContext = new OracleContext();
    const marketContext = new MarketContext();
    await baseContext.setupTestUsers();
    // Deploy all base contracts
    await baseContext.deployContracts1();
    // Give ERC20 to users
    await baseContext.setUpERC20();
    // Create tgUSD LP
    await baseContext.deployStableLP(
        "tgUSD-USDC",
        [baseContext.coins.usdc, baseContext.tgUSD],
        [parseUnits("1000000", 6), parseEther("1000000")],
        "5000",
        "100000000",
        "0",
        "866",
        "0"
    );

    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext.stableLp);

    // Deploy other contracts that needed oracles and LP
    await baseContext.deployContracts2(oracleContext.oracles["tgUSD"]);

    // Define markets to deploy
    const convexCrvMarkets: ConvexCrvMarketKeys[] = ["crvUSD_USDC", "crvUSD_USDT"];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD"];
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);
    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);
    // Approve LPs with test users
    await baseContext.approveCurveLP(await baseContext.stableLp["tgUSD-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);

    // Write JSON with all addresses
    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext), null, 2));

    console.info("\x1b[32m%s\x1b[0m", "Contracts deployed and setup !");
}

type Market = {
    marketAddress: string;
    collatName: string;
    collatAddress: string;
    marketType: string;
};

async function createJSONAddress(baseContext: BaseContext, marketContext: MarketContext, oracleContext: OracleContext) {
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

    return {
        utilities: {
            controlTower: await baseContext.controlTower.getAddress(),
            rewardAccumulator: await baseContext.rewardAccumulator.getAddress(),
            zapper: await baseContext.zapper.getAddress(),
        },
        tokens: {
            tgUSD: await baseContext.tgUSD.getAddress(),
            sgUSD: await baseContext.sgUSD.getAddress(),
        },
        markets,
        oracles,
        lps: {
            tgUSD_USDC_LP: await baseContext.stableLp["tgUSD-USDC"].getAddress(),
        },
    };
}

main();

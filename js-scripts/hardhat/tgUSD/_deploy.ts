import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {ConvexCrvMarketKeys, ConvexFxnMarketKeys, MarketContext} from "./MarketContext";
import * as fs from "fs";
import {curveLp} from "convergence-defi-tools";
import {parseEther, parseUnits} from "ethers";
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
    const convexCrvMarkets: ConvexCrvMarketKeys[] = ["crvUSD_USDC_Cvx_Market", "crvUSD_USDT_Cvx_Market"];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD_Cvx_Market"];
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);
    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);
    // Approve LPs with test users
    await baseContext.approveCurveLP(await baseContext.stableLp["tgUSD-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);

    // Write JSON with all addresses
    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext), null, 2));

    console.log("Contracts deployed and setup !");
}

async function createJSONAddress(baseContext: BaseContext, marketContext: MarketContext, oracleContext: OracleContext) {
    let convexCrvMarkets: {[key: string]: string} = {};
    for (const prop in marketContext.convexCrvMarkets) {
        const market = await marketContext.convexCrvMarkets[prop].getAddress();
        convexCrvMarkets[prop] = market;
    }

    let convexFxnMarkets: {[key: string]: string} = {};
    for (const prop in marketContext.convexFxnMarkets) {
        const market = await marketContext.convexFxnMarkets[prop].getAddress();
        convexFxnMarkets[prop] = market;
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
        },
        markets: {
            convexCrvMarkets,
            convexFxnMarkets,
        },
        oracles,
        lps: {
            tgUSD_USDC_LP: await baseContext.stableLp["tgUSD-USDC"].getAddress(),
        },
    };
}

main();

import {Client} from "pg";
import * as addresses from "../../../../addresses.json";
import * as wStable from "../../../../artifacts/src/tgUSD/tokens/WStable.sol/WStable.json";
import * as curveStableSwapNG from "../../../../artifacts/src/interfaces/externals/Curve/ICurveStableSwapNG.sol/ICurveStableSwapNG.json";

import {curveLp} from "defi-resources";
import {forceAbi} from "./insertContractInDb";
import {artifacts} from "hardhat";

export async function verifyContracts() {
    const client = new Client({
        user: "blockscout",
        host: process.env.BLOCKSCOUT_HOST,
        database: "blockscout",
        password: process.env.BLOCKSCOUT_DB_PASSWORD,
        port: 7432,
    });
    await client.connect();

    // Curve LP

    await forceAbi(client, curveLp.crvUSD_USDC, "crvUSD/USDC", true, curveStableSwapNG.abi);
    await forceAbi(client, curveLp.crvUSD_USDT, "crvUSD/USDT", true, curveStableSwapNG.abi);

    // Utilities
    const controlTower = "ControlTower";
    await forceAbi(client, addresses.utilities.controlTower, controlTower, false, (await artifacts.readArtifact(controlTower)).abi);
    const rewardAccumulator = "RewardAccumulator";
    await forceAbi(client, addresses.utilities.rewardAccumulator, rewardAccumulator, false, (await artifacts.readArtifact(rewardAccumulator)).abi);
    const zapper = "Zapper";
    await forceAbi(client, addresses.utilities.controlTower, zapper, false, (await artifacts.readArtifact(zapper)).abi);
    const marketCreator = "MarketCreator";
    await forceAbi(client, addresses.utilities.controlTower, marketCreator, false, (await artifacts.readArtifact(marketCreator)).abi);

    // // Tokens
    const tgUSD = "TgUSD";
    await forceAbi(client, addresses.tokens.tgUSD, tgUSD, false, (await artifacts.readArtifact(tgUSD)).abi);
    const sgUSD = "SgUSD";
    await forceAbi(client, addresses.tokens.sgUSD, sgUSD, true, (await artifacts.readArtifact("IYearnV3Vault")).abi);
    const tan = "Tan";
    await forceAbi(client, addresses.tokens.tan, tan, false, (await artifacts.readArtifact(tan)).abi);
    const rsTan = "RsTan";
    await forceAbi(client, addresses.tokens.rsTan, rsTan, false, (await artifacts.readArtifact(rsTan)).abi);

    // Markets Convex CRV
    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_CRV") {
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Convex_CRV", false, (await artifacts.readArtifact("ConvexCrvLPMarket")).abi);
        }
    }

    // Markets Convex FXN
    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_FXN") {
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Convex_FXN", false, (await artifacts.readArtifact("ConvexFxnLPMarket")).abi);
        }
    }

    // tgUSD Lps
    for (const [name, address] of Object.entries(addresses.lps)) {
        await forceAbi(client, address, name, true, curveStableSwapNG.abi);
    }

    // WStables
    for (const [name, address] of Object.entries(addresses.wStables)) {
        await forceAbi(client, address, name, false, wStable.abi);
    }

    await client.end();
}
verifyContracts();

// npx hardhat run js-scripts/hardhat/tgUSD/blockscout/verify-contracts.ts

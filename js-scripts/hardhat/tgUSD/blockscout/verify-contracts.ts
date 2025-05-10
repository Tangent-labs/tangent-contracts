import {Client} from "pg";
import * as addresses from "../../../../addresses.json";
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
    await forceAbi(client, curveLp.CRV_LP_USDC_fxUSD, "USDC/fxUSD", true, curveStableSwapNG.abi);
    await forceAbi(client, curveLp.CRV_DUO_frxETH_ETH, "frxETH/ETH", true, curveStableSwapNG.abi);

    // Utilities
    const controlTower = "ControlTower";
    await forceAbi(client, addresses.utilities.controlTower, controlTower, false, (await artifacts.readArtifact(controlTower)).abi);
    const rewardAccumulator = "RewardAccumulator";
    await forceAbi(client, addresses.utilities.rewardAccumulator, rewardAccumulator, false, (await artifacts.readArtifact(rewardAccumulator)).abi);
    const zapper = "Zapper";
    await forceAbi(client, addresses.utilities.controlTower, zapper, false, (await artifacts.readArtifact(zapper)).abi);
    const marketCreator = "MarketCreator";
    await forceAbi(client, addresses.utilities.controlTower, marketCreator, false, (await artifacts.readArtifact(marketCreator)).abi);
    const irCalculator = "IRCalculator";
    await forceAbi(client, addresses.utilities.irCalculator, irCalculator, false, (await artifacts.readArtifact(irCalculator)).abi);
    const pegKeeperRegulator = "PegKeeperRegulator";
    await forceAbi(client, addresses.utilities.pegKeeperRegulator, pegKeeperRegulator, true, (await artifacts.readArtifact(pegKeeperRegulator)).abi);

    // Tokens
    const tgUSD = "TgUSD";
    await forceAbi(client, addresses.tokens.tgUSD, tgUSD, false, (await artifacts.readArtifact(tgUSD)).abi);
    const sgUSD = "SgUSD";
    await forceAbi(client, addresses.tokens.sgUSD, sgUSD, true, (await artifacts.readArtifact("IYearnV3Vault")).abi);
    const tan = "Tan";
    await forceAbi(client, addresses.tokens.tan, tan, false, (await artifacts.readArtifact(tan)).abi);

    // Lock
    const rsTan = "RsTan";
    await forceAbi(client, addresses.lock.rsTan, rsTan, false, (await artifacts.readArtifact(rsTan)).abi);
    // Oracles
    const Oracle_USDC = "Oracle USDC";
    await forceAbi(client, addresses.oracles.USDC, Oracle_USDC, false, (await artifacts.readArtifact("IAggregatorV3")).abi);

    const Oracle_USDT = "Oracle USDT";
    await forceAbi(client, addresses.oracles.USDT, Oracle_USDT, false, (await artifacts.readArtifact("IAggregatorV3")).abi);

    const Oracle_fxUSD = "Oracle fxUSD";
    await forceAbi(client, addresses.oracles.fxUSD, Oracle_fxUSD, false, (await artifacts.readArtifact("StablePriceOracleParams")).abi);

    const Oracle_crvUSD_USDC = "Oracle crvUSD/USDC";
    await forceAbi(client, addresses.oracles.crvUSD_USDC, Oracle_crvUSD_USDC, false, (await artifacts.readArtifact("OracleDuoPoolStable")).abi);

    const Oracle_crvUSD_USDT = "Oracle crvUSD/USDT";
    await forceAbi(client, addresses.oracles.crvUSD_USDT, Oracle_crvUSD_USDT, false, (await artifacts.readArtifact("OracleDuoPoolStable")).abi);

    const Oracle_USDC_fxUSD = "Oracle USDC/fxUSD";
    await forceAbi(client, addresses.oracles.USDC_fxUSD, Oracle_USDC_fxUSD, false, (await artifacts.readArtifact("OracleDuoPoolStable")).abi);

    const Oracle_frxETH_WETH = "Oracle frxETH/WETH";
    await forceAbi(client, addresses.oracles.frxETH_WETH, Oracle_frxETH_WETH, false, (await artifacts.readArtifact("OracleDuoPoolStable")).abi);

    const OracleTgUSD = "Oracle tgUSD";
    await forceAbi(client, addresses.oracles.tgUSD, OracleTgUSD, true, (await artifacts.readArtifact("AggregatorStablePriceV3")).abi);

    // Markets Convex CRV
    const abiMarketConvexCrv = (await artifacts.readArtifact("ConvexCrvLPMarket")).abi;
    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_CRV") {
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Convex_CRV", false, abiMarketConvexCrv);
        }
    }

    // Markets Convex FXN
    const abiMarketConvexFxn = (await artifacts.readArtifact("ConvexFxnLPMarket")).abi;
    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_FXN") {
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Convex_FXN", false, abiMarketConvexFxn);
        }
    }

    // tgUSD Lps
    for (const [name, address] of Object.entries(addresses.lps)) {
        await forceAbi(client, address, name, true, curveStableSwapNG.abi);
    }

    const abiWStable = (await artifacts.readArtifact("WStable")).abi;
    // WStables
    for (const [name, address] of Object.entries(addresses.wStables)) {
        await forceAbi(client, address, name, false, abiWStable);
    }

    const abiPegKeeperV2 = (await artifacts.readArtifact("PegKeeperV2")).abi;
    // PegKeepers
    for (const [name, address] of Object.entries(addresses.pegKeepers)) {
        await forceAbi(client, address, "PegKeeper " + name, true, abiPegKeeperV2);
    }

    await client.end();
}
verifyContracts();
// npx hardhat run js-scripts/hardhat/tgUSD/blockscout/verify-contracts.ts

import {Client} from "pg";
import * as addresses from "../../../../addresses.json";
import * as curveStableSwapNG from "../../../../artifacts/src/interfaces/externals/Curve/ICurveStableSwapNG.sol/ICurveStableSwapNG.json";

import {commonERC20, curveLp, routers} from "defi-resources";
import {forceAbi, nameAddress} from "./insertContractInDb";
import {artifacts, ethers} from "hardhat";

export async function verifyContracts() {
    const client = new Client({
        user: "blockscout",
        host: process.env.BLOCKSCOUT_HOST,
        database: "blockscout",
        password: process.env.BLOCKSCOUT_DB_PASSWORD,
        port: 7432,
    });
    await client.connect();

    const abiERC20 = (await artifacts.readArtifact("ERC20")).abi;

    const users = await ethers.getSigners();
    await nameAddress(client, await users[0].getAddress(), "Owner");
    await nameAddress(client, await users[1].getAddress(), "User 1");
    await nameAddress(client, await users[2].getAddress(), "User 2");
    await nameAddress(client, await users[3].getAddress(), "User 3");
    await nameAddress(client, await users[4].getAddress(), "Fee Treasury");

    await forceAbi(client, routers.CURVE_V1_2_ROUTER, "Curve Router", true, (await artifacts.readArtifact("ICurveRouter")).abi);
    // Curve LP StableSwap NG
    const stableSwapNGAbi = (await artifacts.readArtifact("ICurveStableSwapNG")).abi;

    await forceAbi(client, curveLp.crvUSD_USDC, "crvUSD/USDC", true, stableSwapNGAbi);
    await forceAbi(client, curveLp.crvUSD_USDT, "crvUSD/USDT", true, stableSwapNGAbi);
    await forceAbi(client, curveLp.CRV_LP_USDC_fxUSD, "USDC/fxUSD", true, stableSwapNGAbi);
    await forceAbi(client, curveLp.CRV_DUO_frxETH_ETH, "frxETH/ETH", true, stableSwapNGAbi);
    await forceAbi(client, curveLp.CRV_LP_pxETH_WETH, "pxETH/ETH", true, stableSwapNGAbi);

    // CryptoSwap

    await forceAbi(client, curveLp.CRV_DUO_ETH_CVX_TOKEN, "CVX/ETH Token", true, abiERC20);

    const cryptoSwapAbi = (await artifacts.readArtifact("ICurveCryptoSwap")).abi;
    await forceAbi(client, curveLp.CRV_DUO_ETH_CVX, "CVX/ETH LP", true, cryptoSwapAbi);

    // Utilities
    const controlTower = "ControlTower";
    await forceAbi(client, addresses.utilities.controlTower, controlTower, false, (await artifacts.readArtifact(controlTower)).abi);
    const rewardAccumulator = "RewardAccumulator";
    await forceAbi(client, addresses.utilities.rewardAccumulator, rewardAccumulator, false, (await artifacts.readArtifact(rewardAccumulator)).abi);
    const zappingProxy = "ZappingProxy";
    await forceAbi(client, addresses.utilities.zappingProxy, zappingProxy, false, (await artifacts.readArtifact(zappingProxy)).abi);
    const marketCreator = "MarketCreator";
    await forceAbi(client, addresses.utilities.marketCreator, marketCreator, false, (await artifacts.readArtifact(marketCreator)).abi);
    const irCalculator = "IRCalculator";
    await forceAbi(client, addresses.utilities.irCalculator, irCalculator, false, (await artifacts.readArtifact(irCalculator)).abi);
    const pegKeeperRegulator = "PegKeeperRegulator";
    await forceAbi(client, addresses.utilities.pegKeeperRegulator, pegKeeperRegulator, true, (await artifacts.readArtifact(pegKeeperRegulator)).abi);

    // Tokens
    const USG = "USG";
    await forceAbi(client, addresses.tokens.USG, USG, false, (await artifacts.readArtifact(USG)).abi);
    const sUSG = "sUSG";
    await forceAbi(client, addresses.tokens.sUSG, sUSG, true, (await artifacts.readArtifact("IYearnV3Vault")).abi);
    const tan = "Tan";
    await forceAbi(client, addresses.tokens.tan, tan, false, (await artifacts.readArtifact(tan)).abi);

    // Lock
    const vsTan = "VsTan";
    await forceAbi(client, addresses.tokens.vsTan, vsTan, false, (await artifacts.readArtifact(vsTan)).abi);
    // Oracles
    await forceAbi(client, addresses.oracles.USDC, "Oracle USDC", false, (await artifacts.readArtifact("IAggregatorV3")).abi);

    await forceAbi(client, addresses.oracles.USDT, "Oracle USDT", false, (await artifacts.readArtifact("IAggregatorV3")).abi);

    const abiOracleCoinFromCurveLP = (await artifacts.readArtifact("OracleCoinFromCurveLP")).abi;
    await forceAbi(client, addresses.oracles.fxUSD, "Oracle fxUSD", false, abiOracleCoinFromCurveLP);
    await forceAbi(client, addresses.oracles.frxUSD, "Oracle frxUSD", false, abiOracleCoinFromCurveLP);
    await forceAbi(client, addresses.oracles.frxETH, "Oracle frxETH", false, abiOracleCoinFromCurveLP);
    await forceAbi(client, addresses.oracles.pxETH, "Oracle pxETH", false, abiOracleCoinFromCurveLP);

    const abiOracleDuoPoolStable = (await artifacts.readArtifact("OracleDuoPoolStable")).abi;
    await forceAbi(client, addresses.oracles["crvUSD-USDC"], "Oracle crvUSD/USDC", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["crvUSD-USDT"], "Oracle crvUSD/USDT", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["USDC-fxUSD"], "Oracle USDC/fxUSD", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["USDC-USDT"], "Oracle USDC/USDT", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["frxUSD-USDe"], "Oracle frxUSD/USDe", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["pxETH-WETH"], "Oracle pxETH/WETH", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["pxETH-stETH"], "Oracle pxETH/stETH", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["frxETH-WETH"], "Oracle frxETH/WETH", false, abiOracleDuoPoolStable);
    await forceAbi(client, addresses.oracles["cbBTC-WBTC"], "Oracle cbBTC/WBTC", false, abiOracleDuoPoolStable);

    const abiOracleCryptoSwap = (await artifacts.readArtifact("OracleCryptoSwap")).abi;
    await forceAbi(client, addresses.oracles["USDT-WBTC-WETH"], "Oracle USDC/WBTC/WETH", false, abiOracleCryptoSwap);
    await forceAbi(client, addresses.oracles["USDC-WBTC-WETH"], "Oracle USDC/WBTC/WETH", false, abiOracleCryptoSwap);
    await forceAbi(client, addresses.oracles["crvUSD-ETH-CRV"], "Oracle crvUSD/ETH/CRV", false, abiOracleCryptoSwap);
    await forceAbi(client, addresses.oracles["GHO-cbBTC-WETH"], "Oracle GHO/cbBTC/WETH", false, abiOracleCryptoSwap);
    await forceAbi(client, addresses.oracles["CVX-ETH"], "Oracle CVX/ETH", false, abiOracleCryptoSwap);
    await forceAbi(client, addresses.oracles["USR-RLP"], "Oracle USR/RLP", false, abiOracleCryptoSwap);

    const abiOraclePendlePT = (await artifacts.readArtifact("OraclePendlePT")).abi;
    await forceAbi(client, addresses.oracles["sUSDe 07/31/25"], "Oracle sUSDe 07/31/25", false, abiOraclePendlePT);
    await forceAbi(client, addresses.oracles["wstUSR 07/25/25"], "Oracle wstUSR 07/25/25", false, abiOraclePendlePT);

    await forceAbi(client, addresses.oracles.USG, "Oracle USG", true, (await artifacts.readArtifact("AggregatorStablePriceV3")).abi);

    // Verify ERC4626
    const abi4626 = (await artifacts.readArtifact("IERC4626")).abi;

    const abi_sDOLA = (await artifacts.readArtifact("IsDOLA")).abi;
    await forceAbi(client, commonERC20.sDOLA, "sDOLA", false, abi_sDOLA);

    const abi_sUSDe = (await artifacts.readArtifact("IsUSDe")).abi;
    await forceAbi(client, commonERC20.sUSDe, "sUSDe", false, abi_sUSDe);

    const erc4626Params = [
        {address: commonERC20.wstUSR, name: "wstUSR"},
        {address: commonERC20.sUSDS, name: "sUSDS"},
        // {address: commonERC20.sfrxUSD, name: "sfrxUSD"},
    ];
    for (let i = 0; i < erc4626Params.length; i++) {
        const param = erc4626Params[i];
        await forceAbi(client, param.address, param.name, false, abi4626);
    }

    // Verify ERC20

    const erc20Params = [
        {address: commonERC20.USR, name: "USR"},
        {address: commonERC20.USDe, name: "USDE"},
        {address: commonERC20.DOLA, name: "DOLA"},
        {address: commonERC20.USDS, name: "USDS"},
        {address: commonERC20.crvUSD, name: "crvUSD"},
        // {address: commonERC20.sfrxUSD, name: "sfrxUSD"},
    ];
    for (let i = 0; i < erc20Params.length; i++) {
        const param = erc20Params[i];
        await forceAbi(client, param.address, param.name, false, abiERC20);
    }

    const yearnVaultAbi = (await artifacts.readArtifact("IYearnV3Vault")).abi;
    await forceAbi(client, commonERC20.scrvUSD, "scrvUSD", true, yearnVaultAbi);

    // Verify CVX Booster
    const cvxCurveBoosterAddress = "0xF403C135812408BFbE8713b5A23a04b3D48AAE31";
    const abiCvxBooster = (await artifacts.readArtifact("ICvxBooster")).abi;
    await forceAbi(client, cvxCurveBoosterAddress, "CVX CRV Booster", false, abiCvxBooster);
    const booster = await ethers.getContractAt("ICvxBooster", cvxCurveBoosterAddress);

    // Markets Convex CRV
    const abiMarketConvexCrv = (await artifacts.readArtifact("ConvexCrvLPMarket")).abi;
    const abiCvxRewardToken = (await artifacts.readArtifact("ICvxRewardToken")).abi;

    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_CRV") {
            const marketAddress = marketObject.marketAddress;
            const marketContract = await ethers.getContractAt("ConvexCrvLPMarket", marketAddress);
            const cvxRewardToken = await ethers.getContractAt("ICvxRewardToken", await marketContract.cvxRewardToken());

            const pid = await cvxRewardToken.pid();
            const infos = await booster.poolInfo(pid);

            // Verify Market
            await forceAbi(client, marketAddress, "Market " + marketObject.collatName + " Convex_CRV", false, abiMarketConvexCrv);
            // Verify Cvx Reward token
            await forceAbi(client, await cvxRewardToken.getAddress(), "CvxRewardToken " + marketObject.collatName, false, abiCvxRewardToken);

            // Verify Staking token Convex
            await forceAbi(client, infos.token, "ConvexVault " + marketObject.collatName, false, abiERC20);

            // Gauge Curve
            await forceAbi(client, infos.gauge, "CurveGauge " + marketObject.collatName, false, abiERC20);
        }
    }

    // Markets Convex FXN
    const cvxFxnBoosterAddress = "0x989AEb4d175e16225E39E87d0D97A3360524AD80";
    // Verify FXN booster
    await forceAbi(client, cvxFxnBoosterAddress, "Convex FXN Booster", false, abiCvxBooster);

    const abiMarketConvexFxn = (await artifacts.readArtifact("ConvexFxnLPMarket")).abi;
    const abiStakingProxyERC20 = (await artifacts.readArtifact("IStakingProxyERC20")).abi;

    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Convex_FXN") {
            const marketAddress = marketObject.marketAddress;
            const marketContract = await ethers.getContractAt("ConvexFxnLPMarket", marketAddress);
            const stakingProxy = await ethers.getContractAt("IStakingProxyERC20", await marketContract.stakingProxyVault());
            // Market verification
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Convex_FXN", false, abiMarketConvexFxn);
            // Convex Staking FXN
            await forceAbi(client, await stakingProxy.getAddress(), "ConvexStakingProxyFxn " + marketObject.collatName, false, abiStakingProxyERC20);
            // FXN Gauge verification
            await forceAbi(client, await stakingProxy.gaugeAddress(), "FxnGauge " + marketObject.collatName, false, abiERC20);

            // const infos = await booster.poolInfo(pid);

            // Gauge Curve
            // await forceAbi(client, infos.gauge, "CurveGauge " + marketObject.collatName, false, abiERC20);
        }
    }

    const abiNoSociabilization = (await artifacts.readArtifact("BasicERC20Market")).abi;

    // Markets Pendle PT
    for (const marketObject of Object.values(addresses.markets)) {
        if (marketObject.marketType === "Pendle_PT") {
            await forceAbi(client, marketObject.marketAddress, "Market " + marketObject.collatName + " Pendle_PT", false, abiNoSociabilization);
        }
    }

    // USG Lps
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
// npx hardhat run js-scripts/hardhat/USG/blockscout/verify-contracts.ts

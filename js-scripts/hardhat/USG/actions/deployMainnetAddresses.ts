import { mine, impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { CURVE_LPS } from "@tangent/defi-resources";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";
import { BaseContext } from "../contexts/BaseContext";
import { LpDeployContext } from "../contexts/LPDeployContext";
import { ConvexFxnMarketKeys, CurveGaugeMarketsKeys, MarketContext, StakeDaoVaultV2MarketsKeys } from "../contexts/MarketContext";
import { DebtIR } from "../../../../typechain-types";
import { OracleContext } from "../contexts/OracleContext";
import { WStablesContext } from "../contexts/WStableContext";

type ProdMarketAddresses = Record<string, string>;

function getProdMarketAddress(prodMarkets: ProdMarketAddresses, key: string) {
    const reversedKey = key.split("_").reverse().join("_");
    return prodMarkets[key] ?? prodMarkets[reversedKey];
}

async function isDeployedProdMarket(address: string): Promise<boolean> {
    const code = await ethers.provider.getCode(address);
    return !!code && code !== "0x" && code !== "0x0";
}

async function isCleanProdMarket(address: string): Promise<boolean> {
    try {
        const market = await ethers.getContractAt([
            "function totalDebtShares() external view returns (uint256)",
            "function badDebt() external view returns (uint256)",
        ], address);
        const [totalDebtShares, badDebt] = await Promise.all([market.totalDebtShares(), market.badDebt()]);
        return totalDebtShares === 0n && badDebt === 0n;
    } catch (err) {
        console.warn(`Unable to verify prod market cleanliness for ${address}; falling back to local deploy.`);
        return false;
    }
}

async function bumpProdMarketMaxDebt(baseContext: BaseContext, market: DebtIR, key: string) {
    const currentMaxDebt = await market.maxMarketDebt();
    const newMaxDebt = currentMaxDebt + ethers.parseEther("1000000");
    console.log(`Bump prod market ${key} maxMarketDebt from ${ethers.formatEther(currentMaxDebt)} to ${ethers.formatEther(newMaxDebt)}`);
    await impersonateAccount(await baseContext.owner.getAddress());
    await market.connect(baseContext.owner).setMaxMarketDebt(newMaxDebt);
    await stopImpersonatingAccount(await baseContext.owner.getAddress());
}

async function useProdStakeDaoVaultMarkets(baseContext: BaseContext, marketContext: MarketContext, keys: StakeDaoVaultV2MarketsKeys[], isLiquidationContext: boolean) {
    if (!isLiquidationContext) {
        return keys;
    }

    const missingKeys: StakeDaoVaultV2MarketsKeys[] = [];
    const prodMarkets = PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT as ProdMarketAddresses;

    for (const key of keys) {
        const prodAddress = getProdMarketAddress(prodMarkets, key);
        if (!prodAddress) {
            missingKeys.push(key);
            continue;
        }

        if (!(await isDeployedProdMarket(prodAddress))) {
            console.log(`Prod StakeDao VaultV2 market ${key} at ${prodAddress} is not deployed at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        if (!(await isCleanProdMarket(prodAddress))) {
            console.log(`Prod StakeDao VaultV2 market ${key} at ${prodAddress} already has existing debt at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        const market = await ethers.getContractAt("StakeDaoVaultV2Market", prodAddress);
        marketContext.stakeDaoVaultMarkets[key] = market;
        console.log(`Use prod StakeDao VaultV2 market ${key}: ${prodAddress}`);
        await bumpProdMarketMaxDebt(baseContext, market as unknown as DebtIR, key);
    }

    return missingKeys;
}

async function useProdCurveGaugeMarkets(baseContext: BaseContext, marketContext: MarketContext, keys: CurveGaugeMarketsKeys[], isLiquidationContext: boolean) {
    if (!isLiquidationContext) {
        return keys;
    }

    const missingKeys: CurveGaugeMarketsKeys[] = [];
    const prodMarkets = PROD_ADDRESSES.MARKETS.CURVE_GAUGE as ProdMarketAddresses;

    for (const key of keys) {
        const prodAddress = getProdMarketAddress(prodMarkets, key);
        if (!prodAddress) {
            missingKeys.push(key);
            continue;
        }

        if (!(await isDeployedProdMarket(prodAddress))) {
            console.log(`Prod Curve Gauge market ${key} at ${prodAddress} is not deployed at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        if (!(await isCleanProdMarket(prodAddress))) {
            console.log(`Prod Curve Gauge market ${key} at ${prodAddress} already has existing debt at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        const market = await ethers.getContractAt("CurveGaugeMarket", prodAddress);
        marketContext.curveGaugeMarkets[key] = market;
        console.log(`Use prod Curve Gauge market ${key}: ${prodAddress}`);
        await bumpProdMarketMaxDebt(baseContext, market as unknown as DebtIR, key);
    }

    return missingKeys;
}

async function useProdConvexFxnMarkets(baseContext: BaseContext, marketContext: MarketContext, keys: ConvexFxnMarketKeys[], isLiquidationContext: boolean) {
    

    const missingKeys: ConvexFxnMarketKeys[] = [];
    const prodMarkets = PROD_ADDRESSES.MARKETS.CONVEX_FXN as ProdMarketAddresses;

    for (const key of keys) {
        const prodAddress = getProdMarketAddress(prodMarkets, key);
        if (!prodAddress) {
            missingKeys.push(key);
            continue;
        }

        if (!(await isDeployedProdMarket(prodAddress))) {
            console.log(`Prod Convex FXN market ${key} at ${prodAddress} is not deployed at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        if (isLiquidationContext && !(await isCleanProdMarket(prodAddress))) {
            console.log(`Prod Convex FXN market ${key} at ${prodAddress} already has existing debt at fork block; falling back to local deploy.`);
            missingKeys.push(key);
            continue;
        }

        const market = await ethers.getContractAt("ConvexFxnLPMarket", prodAddress);
        marketContext.convexFxnMarkets[key] = market;
        console.log(`Use prod Convex FXN market ${key}: ${prodAddress}`);
        await bumpProdMarketMaxDebt(baseContext, market as unknown as DebtIR, key);
    }

    return missingKeys;
}

export async function deployMainnetAddresses(userCount: number = 5, baseLpDeposit?: number, isLiquidationContext: boolean = false) {
    const baseContext = new BaseContext(userCount);
    const oracleContext = new OracleContext();
    const marketContext = new MarketContext();
    const lpDeployContext = new LpDeployContext();
    const wStableContext = new WStablesContext();


    await mine(1)

    console.log("Setup Users");
    await baseContext.setupTestUsers();

    console.log("Fetches Mainnet contracts");
    await baseContext.fetchMainnetContracts();

    console.log("Give ERC20 to users");
    await baseContext.setUpERC20();

    // console.log("Setup the context for Onchain boost ( lockers + stAssets + NFT)");
    // await executeBoostContext()

    const seedLpAmount = baseLpDeposit ?? 10_000;
    await lpDeployContext.fetchLPsAndSeedLps(baseContext, seedLpAmount);

    console.log("Deploy and setup Oracles");
    // Setup and create all oracles
    await oracleContext.fetchUSGOracleAndDeployMarketOracles();


    const stakeDaoVaultMarkets: StakeDaoVaultV2MarketsKeys[] = [
        "frxUSD_sUSDS",
        "BOLD_USDC",
        "eUSD_USDC",
        "reUSD_scrvUSD",
        "USDT_crvUSD",
        "frxUSD_OUSD",
        "frxUSD_sDOLA",
        "frxUSD_scrvUSD",
    ];

    const curveGaugeMarkets: CurveGaugeMarketsKeys[] = [
        "PYUSD_USDC",
        "RLUSD_USDC",
        // "stUSDS_USDS"
    ];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = [
        "USDC_fxUSD",
        "fxUSD_reUSD"
    ];


    // Deploy StakeDAO Vault markets
    const missingStakeDaoVaultMarkets = await useProdStakeDaoVaultMarkets(baseContext, marketContext, stakeDaoVaultMarkets, isLiquidationContext);
    if (missingStakeDaoVaultMarkets.length > 0) {
        console.log("Deploy missing StakeDao VaultV2 markets");
        await marketContext.deployStakeDaoVaultV2Markets(missingStakeDaoVaultMarkets, baseContext, oracleContext, baseContext.users);
    }

    // Deploy Curve Gauge markets
    const missingCurveGaugeMarkets = await useProdCurveGaugeMarkets(baseContext, marketContext, curveGaugeMarkets, isLiquidationContext);
    if (missingCurveGaugeMarkets.length > 0) {
        console.log("Deploy missing Curve Gauge markets");
        await marketContext.deployCurveGaugeMarkets(missingCurveGaugeMarkets, baseContext, oracleContext, baseContext.users);
    }


    // Deploy Convex FXN markets
    const missingConvexFxnMarkets = await useProdConvexFxnMarkets(baseContext, marketContext, convexFxnMarkets, isLiquidationContext);
    if (missingConvexFxnMarkets.length > 0) {
        console.log("Deploy missing convex FXN markets");
        await marketContext.deployConvexFxnMarkets(missingConvexFxnMarkets, baseContext, oracleContext);
    }


    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-USDC"].getAddress());
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-frxUSD"].getAddress());
    await baseContext.approveCurveLP(CURVE_LPS.crvUSD_USDC);

    return { baseContext, oracleContext, marketContext, lpDeployContext, wStableContext };
}


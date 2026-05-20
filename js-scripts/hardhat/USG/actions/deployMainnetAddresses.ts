import { mine } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { CURVE_LPS } from "@tangent/defi-resources";
import { BaseContext } from "../contexts/BaseContext";
import { LpDeployContext } from "../contexts/LPDeployContext";
import { ConvexFxnMarketKeys, CurveGaugeMarketsKeys, MarketContext, StakeDaoVaultV2MarketsKeys } from "../contexts/MarketContext";
import { OracleContext } from "../contexts/OracleContext";
import { WStablesContext } from "../contexts/WStableContext";

export async function deployMainnetAddresses(userCount: number = 5, baseLpDeposit?: number) {
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
        "scrvUSD_sUSDe",
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
    console.log("Deploy StakeDao VaultV2 markets");
    await marketContext.deployStakeDaoVaultV2Markets(stakeDaoVaultMarkets, baseContext, oracleContext, baseContext.users);

    // Deploy Curve Gauge markets
    console.log("Deploy Curve Gauge markets");
    await marketContext.deployCurveGaugeMarkets(curveGaugeMarkets, baseContext, oracleContext, baseContext.users);


    // Deploy Convex FXN markets
    console.log("Deploy convex FXN markets");
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);


    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-USDC"].getAddress());
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-frxUSD"].getAddress());
    await baseContext.approveCurveLP(CURVE_LPS.crvUSD_USDC);

    return { baseContext, oracleContext, marketContext, lpDeployContext, wStableContext };
}


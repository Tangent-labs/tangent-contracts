import { CURVE_LPS } from "@tangent/defi-resources";
import { BaseContext } from "../contexts/BaseContext";
import { MarketContext, ConvexCrvMarketKeys, ConvexFxnMarketKeys, BasicERC20MarketKeys, StakeDaoVaultV2MarketsKeys, CurveGaugeMarketsKeys } from "../contexts/MarketContext";
import { OracleContext } from "../contexts/OracleContext";
import { LpDeployContext } from "../contexts/LPDeployContext";
import { WStablesContext } from "../contexts/WStableContext";
import { executeBoostContext } from "../contexts/OnchainBoostContext";
import { mine } from "@nomicfoundation/hardhat-toolbox/network-helpers";

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

    console.log("Seed USG LPs");
    await lpDeployContext.fetchLPsAndSeedLps(baseContext, 10_000);

    console.log("Deploy and setup Oracles");
    // Setup and create all oracles
    await oracleContext.fetchUSGOracleAndDeployMarketOracles();

    // Define markets to deploy
    const convexCrvMarkets: ConvexCrvMarketKeys[] = [
        // Stable USD
        "crvUSD_USDC",
        "crvUSD_USDT",
        "USDC_USDT",
        // "frxUSD_USDe",

        // Stable ETH
        "frxETH_WETH",
        // "pxETH_WETH",
        // "pxETH_stETH",

        // Stable BTC
        // "cbBTC_WBTC

    ];

    const stakeDaoVaultMarkets: StakeDaoVaultV2MarketsKeys[] = [
        "crvUSD_USDC",
        "crvUSD_USDT",
        "GHO_crvUSD",
        "frxUSD_msUSD",
        "msETH_OETH",
        "ETHPlus_WETH",
        "tBTC_cbBTC",
    ];

    const curveGaugeMarkets: CurveGaugeMarketsKeys[] = [
        "PYUSD_USDC",
        "RLUSD_USDC",
        "stUSDS_USDS"
    ];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = [
        "USDC_fxUSD",
        "fxUSD_reUSD",
        "GHO_fxUSD",
        "msUSD_fxUSD",
    ];

    const pendlePTMarkets: BasicERC20MarketKeys[] = [
        // "Pendle PT - wstUSR 25/06/26",
        "Pendle PT - sUSDe 07/05/26",
        "Pendle PT - USDe 07/05/26"
    ];


    // Deploy StakeDAO Vault markets
    console.log("Deploy StakeDao VaultV2 markets");
    await marketContext.deployStakeDaoVaultV2Markets(stakeDaoVaultMarkets, baseContext, oracleContext, baseContext.users);

    // Deploy Curve Gauge markets
    console.log("Deploy Curve Gauge markets");
    await marketContext.deployCurveGaugeMarkets(curveGaugeMarkets, baseContext, oracleContext, baseContext.users);

    // Deploy Convex CRV markets
    console.log("Deploy convex CRV markets");
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);

    // Deploy Convex FXN markets
    console.log("Deploy convex FXN markets");
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);

    // Deploy Pendle PT markets
    console.log("Deploy Pendle PT markets");
    await marketContext.deployBasicERC20Markets(pendlePTMarkets, baseContext, oracleContext);

    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-USDC"].getAddress());
    await baseContext.approveCurveLP(CURVE_LPS.crvUSD_USDC);

    return { baseContext, oracleContext, marketContext, lpDeployContext, wStableContext };
}


import { curveLp } from "@tangent/defi-resources";
import { BaseContext } from "../contexts/BaseContext";
import { MarketContext, ConvexCrvMarketKeys, ConvexFxnMarketKeys, BasicERC20MarketKeys, StakeDaoVaultV2MarketsKeys, CurveGaugeMarketsKeys } from "../contexts/MarketContext";
import { OracleContext } from "../contexts/OracleContext";
import { LpDeployContext } from "../contexts/LPDeployContext";
import { WStablesContext } from "../contexts/WStableContext";
import { executeBoostContext } from "../contexts/OnchainBoostContext";

export async function deployUSG(userCount: number = 6, baseLpDeposit?: number) {
    const baseContext = new BaseContext(userCount);
    const oracleContext = new OracleContext();
    const marketContext = new MarketContext();
    const lpDeployContext = new LpDeployContext();
    const wStableContext = new WStablesContext();

    console.log("Setup Users");
    await baseContext.setupTestUsers();

    console.log("Deploy first part of contracts");
    // Deploy all base contracts
    await baseContext.deployContracts1();

    console.log("Give ERC20 to users");
    // Give ERC20 to users
    await baseContext.setUpERC20();

    console.log("Setup the context for Onchain boost ( lockers + stAssets + NFT)");
    await executeBoostContext()

    console.log("Deploy WStables");
    await wStableContext.deployWStables(baseContext);

    console.log("Deploy LPs");
    // Create USG LP
    await lpDeployContext.deployAllTangentLps(baseContext, wStableContext, baseLpDeposit);

    console.log("Deploy and setup Oracles");
    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext, lpDeployContext);

    console.log("Deploy the second part of contracts");
    // Deploy other contracts that needed oracles and LP
    await baseContext.deployContracts2(oracleContext.USGOracle, lpDeployContext);

    // Define markets to deploy
    const convexCrvMarkets: ConvexCrvMarketKeys[] = [
        // Stable USD
        "crvUSD_USDC",
        "crvUSD_USDT",
        "USDC_USDT",
        "frxUSD_USDe",

        // Stable ETH
        "frxETH_WETH",
        "pxETH_WETH",
        "pxETH_stETH",

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
        "tBTC_cbBTC"
    ];

    const curveGaugeMarkets: CurveGaugeMarketsKeys[] = [
        "PYUSD_USDC",
        "RLUSD_USDC",
        "stUSDS_USDS"
    ];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD", "fxUSD_reUSD", "GHO_fxUSD", "msUSD_fxUSD"];

    const pendlePTMarkets: BasicERC20MarketKeys[] = [
        "Pendle PT - reUSD 25/06/26",
        "Pendle PT - wstUSR 29/01/26",
        "Pendle PT - sUSDe 05/02/26",
        // "Pendle PT - wstETH 25_06_26"
    ];

    // Deploy Convex CRV markets
    console.log("Deploy convex CRV markets");
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);

    // Deploy Convex FXN markets
    console.log("Deploy convex FXN markets");
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);

    // Deploy Curve Gauge markets
    console.log("Deploy Curve Gauge markets");
    await marketContext.deployCurveGaugeMarkets(curveGaugeMarkets, baseContext, oracleContext, baseContext.users);

    // Deploy StakeDAO Vault markets
    console.log("Deploy StakeDao VaultV2 markets");
    await marketContext.deployStakeDaoVaultV2Markets(stakeDaoVaultMarkets, baseContext, oracleContext, baseContext.users);

    // Deploy Pendle PT markets
    console.log("Deploy Pendle PT markets");
    await marketContext.deployBasicERC20Markets(pendlePTMarkets, baseContext, oracleContext);

    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);
    await baseContext.approveCurveLP(curveLp.CRV_LP_USDC_fxUSD);
    await baseContext.approveCurveLP(curveLp.CRV_LP_pxETH_WETH);
    await baseContext.approveCurveLP(curveLp.CRV_DUO_ETH_CVX);

    return { baseContext, oracleContext, marketContext, lpDeployContext, wStableContext };
}

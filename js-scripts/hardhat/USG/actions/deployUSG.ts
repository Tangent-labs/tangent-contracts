import {curveLp} from "@tangent/defi-resources";
import {BaseContext} from "../contexts/BaseContext";
import {MarketContext, ConvexCrvMarketKeys, ConvexFxnMarketKeys, PendlePTMarketsKeys} from "../contexts/MarketContext";
import {OracleContext} from "../contexts/OracleContext";
import {LpDeployContext} from "../contexts/LPDeployContext";
import {WStablesContext} from "../contexts/WStableContext";

export async function deployUSG(userCount: number = 5) {
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

    console.log("Deploy WStables");
    await wStableContext.deployWStables(baseContext);

    console.log("Deploy LPs");
    // Create USG LP
    await lpDeployContext.deployAllTangentLps(baseContext, wStableContext);

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
        "cbBTC_WBTC",

        // TriCrypto
        "crvUSD_ETH_CRV",
        "GHO_cbBTC_WETH",
        "USDC_WBTC_WETH",
        "USDT_WBTC_WETH",

        // DuoCrypto
        "USR_RLP",
        "CVX_ETH",
    ];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD"];

    const pendlePTMarkets: PendlePTMarketsKeys[] = ["USDe_27_11_25", "sUSDe_27_11_25"];

    console.log("Deploy convex CRV markets");
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);

    console.log("Deploy convex FXN markets");
    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);

    console.log("Deploy Pendle PT markets");
    // Deploy Pendle PT markets
    await marketContext.deployPendlePTMarkets(pendlePTMarkets, baseContext, oracleContext);

    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["USG-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);
    await baseContext.approveCurveLP(curveLp.CRV_LP_USDC_fxUSD);
    await baseContext.approveCurveLP(curveLp.CRV_LP_pxETH_WETH);
    await baseContext.approveCurveLP(curveLp.CRV_DUO_ETH_CVX);

    return {baseContext, oracleContext, marketContext, lpDeployContext, wStableContext};
}

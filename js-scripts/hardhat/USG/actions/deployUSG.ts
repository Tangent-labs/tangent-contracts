import {curveLp} from "defi-resources";
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

    await baseContext.setupTestUsers();

    // Deploy all base contracts
    await baseContext.deployContracts1();

    // Give ERC20 to users
    await baseContext.setUpERC20();

    await wStableContext.deployWStables(baseContext);
    // Create USG LP
    await lpDeployContext.deployAllUSGLps(baseContext, wStableContext);

    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext, lpDeployContext);

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

    const pendlePTMarkets: PendlePTMarketsKeys[] = ["sUSDe_31_07_25", "wstUSR_25_07_25"];
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);

    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);

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

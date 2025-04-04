import {curveLp} from "defi-resources";
import {BaseContext} from "../contexts/BaseContext";
import {MarketContext, ConvexCrvMarketKeys, ConvexFxnMarketKeys} from "../contexts/MarketContext";
import {OracleContext} from "../contexts/OracleContext";
import {LpDeployContext} from "../contexts/LPDeployContext";
import {WStablesContext} from "../contexts/WStableContext";

export async function deploytgUsd(userCount: number = 5) {
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
    // Create tgUSD LP
    await lpDeployContext.deployAllTgUSDLps(baseContext, wStableContext);
    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext, lpDeployContext);
    // Deploy other contracts that needed oracles and LP
    await baseContext.deployContracts2(oracleContext.tgUSDOracle, lpDeployContext);

    // Define markets to deploy
    const convexCrvMarkets: ConvexCrvMarketKeys[] = ["crvUSD_USDC", "crvUSD_USDT"];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD"];
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);
    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);
    // Approve LPs with test users
    await baseContext.approveCurveLP(await lpDeployContext.stableLp["tgUSD-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);

    return {baseContext, oracleContext, marketContext, lpDeployContext, wStableContext};
}

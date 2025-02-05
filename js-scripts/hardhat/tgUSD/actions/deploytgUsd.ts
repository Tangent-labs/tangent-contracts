import {curveLp} from "convergence-defi-tools";
import {parseUnits, parseEther} from "ethers";
import {BaseContext} from "../contexts/BaseContext";
import {MarketContext, ConvexCrvMarketKeys, ConvexFxnMarketKeys} from "../contexts/MarketContext";
import {OracleContext} from "../contexts/OracleContext";

export async function deploytgUsd(userCount: number = 5) {
    const baseContext = new BaseContext(userCount);
    const oracleContext = new OracleContext();
    const marketContext = new MarketContext();
    await baseContext.setupTestUsers();
    // Deploy all base contracts
    await baseContext.deployContracts1();
    // Give ERC20 to users
    await baseContext.setUpERC20();
    // Create tgUSD LP
    await baseContext.deployStableLP(
        "tgUSD-USDC",
        [baseContext.coins.usdc, baseContext.tgUSD],
        [parseUnits("1000000", 6), parseEther("1000000")],
        "5000",
        "100000000",
        "0",
        "866",
        "0"
    );

    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext.stableLp);

    // Deploy other contracts that needed oracles and LP
    await baseContext.deployContracts2(oracleContext.oracles["tgUSD"]);

    // Define markets to deploy
    const convexCrvMarkets: ConvexCrvMarketKeys[] = ["crvUSD_USDC", "crvUSD_USDT"];
    const convexFxnMarkets: ConvexFxnMarketKeys[] = ["USDC_fxUSD"];
    // Deploy Convex CRV markets
    await marketContext.deployConvexCrvMarkets(convexCrvMarkets, baseContext, oracleContext);
    // Deploy Convex FXN markets
    await marketContext.deployConvexFxnMarkets(convexFxnMarkets, baseContext, oracleContext);
    // Approve LPs with test users
    await baseContext.approveCurveLP(await baseContext.stableLp["tgUSD-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.crvUSD_USDC);

    return {baseContext, oracleContext, marketContext};
}

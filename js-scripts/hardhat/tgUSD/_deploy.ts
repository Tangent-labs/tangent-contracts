import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {MarketContext} from "./MarketContext";
import * as fs from "fs";
import {curveLp} from "convergence-defi-tools";
import {parseEther, parseUnits} from "ethers";
async function main() {
    const baseContext = new BaseContext();
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
    await baseContext.deployContracts2(oracleContext.tgUSD);
    // Deploy markets
    await marketContext.deployConvexCrvMarkets("crvUSD_USDC_Cvx_Market", baseContext, oracleContext);
    await marketContext.deployConvexFxnMarkets("USDC_fxUSD_Cvx_Market", baseContext, oracleContext);

    await baseContext.approveCurveLP(await baseContext.stableLp["tgUSD-USDC"].getAddress());
    await baseContext.approveCurveLP(curveLp.CRVUSD_USDC);

    let contracts: {[name: string]: string} = {
        controlTower: await baseContext.controlTower.getAddress(),
        rewardAccumulator: await baseContext.rewardAccumulator.getAddress(),
        zapper: await baseContext.zapper.getAddress(),
        tgUSD_USDC_LP: await baseContext.stableLp["tgUSD-USDC"].getAddress(),
        crvUSD_USDC_Cvx_Market: await marketContext.markets["crvUSD_USDC_Cvx_Market"].getAddress(),
        USDC_fxUSD_Cvx_Market: await marketContext.markets["USDC_fxUSD_Cvx_Market"].getAddress(),
        tgUSD: await baseContext.tgUSD.getAddress(),
    };
    fs.writeFileSync("./coucou.json", JSON.stringify(contracts));
}
main();

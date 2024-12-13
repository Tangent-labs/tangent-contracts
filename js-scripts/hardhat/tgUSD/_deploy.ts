import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {MarketContext} from "./MarketContext";
import * as fs from "fs";
import {curveLp} from "convergence-defi-tools";
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
    await baseContext.deployTgUSD_USDC_LP();
    // Setup and create all oracles
    await oracleContext.deployAndSetupOracles(baseContext.tgUSD_USDC_LP);
    // Deploy other contracts that needed oracles and LP
    await baseContext.deployContracts2(oracleContext.tgUSD);
    // Deploy markets
    await marketContext.deployMarkets(baseContext, oracleContext);

    await baseContext.approveCurveLP(await baseContext.tgUSD_USDC_LP.getAddress());
    await baseContext.approveCurveLP(curveLp.CRVUSD_USDC);

    let contracts: {[name: string]: string} = {
        controlTower: await baseContext.controlTower.getAddress(),
        rewardAccumulator: await baseContext.rewardAccumulator.getAddress(),
        zapper: await baseContext.zapper.getAddress(),
        tgUSD_USDC_LP: await baseContext.tgUSD_USDC_LP.getAddress(),
        crvUSD_USDC_Cvx_Market: await marketContext.Cvx_crvUSD_USDC.getAddress(),
    };
    fs.writeFileSync("./coucou.json", JSON.stringify(contracts));
}
main();

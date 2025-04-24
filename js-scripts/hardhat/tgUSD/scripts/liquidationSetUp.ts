import {createJSONAddress} from "../contexts/BaseContext";
import {LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";

async function main() {
    const liquidationContext = new LiquidationContext();
    await liquidationContext.doDeploy();
    fs.writeFileSync(
        "./addresses.json",
        JSON.stringify(
            await createJSONAddress(
                liquidationContext.baseContext!,
                liquidationContext.marketContext!,
                liquidationContext.oracleContext!,
                liquidationContext.lpDeployContext!,
                liquidationContext.wStableContext!
            ),
            null,
            2
        )
    );

    await liquidationContext.doDepositAndBorrow();
    console.info("\x1b[32m%s\x1b[0m", "Liquidation context is setup !");

    await liquidationContext.testChainView();
    console.info("\x1b[32m%s\x1b[0m", "testChainView OK");

    await liquidationContext.unbalanceContext();
    console.info("\x1b[32m%s\x1b[0m", "unbalanceContext OK");
}
main();

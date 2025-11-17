import {LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";
import * as path from "path";

async function main() {
    const liquidationContext = new LiquidationContext();
    await liquidationContext.doDeploy();

    // Create addresses.json
    fs.writeFileSync("./addresses.json", JSON.stringify(liquidationContext.jsonAddressData, null, 2));

    // Create addresses_liquidation.json
    const liquidationFilePath = path.join(process.cwd(), "addresses.json");
    fs.writeFileSync(liquidationFilePath, JSON.stringify(liquidationContext.jsonAddressData, null, 2));
    console.log(`addresses.json created at: ${liquidationFilePath}`);

    await liquidationContext.doDepositAndBorrow();
    console.info("\x1b[32m%s\x1b[0m", "Liquidation context is setup !");

    await liquidationContext.setOraclesToMock();
    console.info("\x1b[32m%s\x1b[0m", "mockOracle OK");
}
main();

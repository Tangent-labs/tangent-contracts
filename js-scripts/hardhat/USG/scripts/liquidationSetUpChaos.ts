import {LiquidationChaosContext} from "../contexts/LiquidationChaosContext";
import * as fs from "fs";
import {ethers, network} from "hardhat";
import * as path from "path";

async function main() {
    await network.provider.send("evm_mine", []);

    const liquidationContext = new LiquidationChaosContext();
    await liquidationContext.doDeploy();

    // Create addresses.json
    fs.writeFileSync("./addresses.json", JSON.stringify(liquidationContext.jsonAddressData, null, 2));

    // Create addresses_liquidation.json
    const liquidationFilePath = path.join(process.cwd(), "addresses.json");
    fs.writeFileSync(liquidationFilePath, JSON.stringify(liquidationContext.jsonAddressData, null, 2));
    console.log(`addresses.json created at: ${liquidationFilePath}`);

    await liquidationContext.doDepositAndBorrow();
    console.info("\x1b[32m%s\x1b[0m", "Liquidation chaos context is setup !");

    await liquidationContext.setOraclesToMock();
    console.info("\x1b[32m%s\x1b[0m", "mockOracle OK");

    await network.provider.send("evm_setAutomine", [false]);
}
main();

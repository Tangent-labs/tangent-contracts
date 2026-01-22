import {LiquidationConfig, LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";
import {network} from "hardhat";
import * as path from "path";

export const SIMPLE_CONFIG: LiquidationConfig = {
    USER_COUNT: 5,
    INITIAL_USG_SUPPLY: 500_000,
    ORACLE_PRICE_DROP_PERCENT: 66n,
    BASE_DEPOSIT: 2000,
    USERS_TO_USE: 2,
    INCLUDED_MARKETS: ["sUSDe 05/02/26",'wstUSR 29/01/26'],
    MODE: "simple",
} as const;

async function main() {
    await network.provider.send("evm_mine", []);
    const liquidationContext = new LiquidationContext(SIMPLE_CONFIG);
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

    await network.provider.send("evm_setAutomine", [false]);
}
main();

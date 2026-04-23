import {LiquidationConfig, LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";
import {network} from "hardhat";
import * as path from "path";
import {ethers} from "hardhat";

export const SIMPLE_CONFIG: LiquidationConfig = {
    USER_COUNT: 5,
    ORACLE_PRICE_DROP_PERCENT: 66n,
    SEED_USG_LP_AMOUNT: 2_500_000,
    USERS_TO_USE: 2,
    INCLUDED_MARKETS: [],
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

    const addresses = JSON.parse(fs.readFileSync(liquidationFilePath, "utf8"));
    const usg = await ethers.getContractAt("IERC20", addresses.tokens.USG);
    const usgUsdcPool = addresses.lps["USG-USDC"];
    const usgFrxUsdPool = addresses.lps["USG-frxUSD"];

    console.log(`USG balance in USG-USDC pool: ${ethers.formatEther(await usg.balanceOf(usgUsdcPool))}`);
    console.log(`USG balance in USG-frxUSD pool: ${ethers.formatEther(await usg.balanceOf(usgFrxUsdPool))}`);

    await network.provider.send("evm_setAutomine", [false]);
}
main();

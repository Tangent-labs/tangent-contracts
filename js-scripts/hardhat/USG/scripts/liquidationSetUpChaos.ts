import {LiquidationConfig, LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";
import {network} from "hardhat";
import * as path from "path";

export const CHAOS_CONFIG: LiquidationConfig = {
    USER_COUNT: 80,
    MAX_POSITION_COUNT: 300,
    INITIAL_USG_SUPPLY: 1_500_000,
    MIN_BORROW_USG: 1000n * 10n ** 18n,
    ORACLE_PRICE_DROP_PERCENT: 66n,
    DEBT_SAFETY_MARGIN_PERCENT: 5n,
    SKIP_USER_PROBABILITY: 0.2,
    EXCLUDED_MARKETS: ["frxUSD_USDe", "pxETH_WETH", "pxETH_stETH", "frxETH_WETH", "USDe 27/11/25", "sUSDe 27/11/25"],
    POSITION_SIZE: {
        SMALL: {value: 5_000n, probability: 0.8},
        MEDIUM: {min: 5_000n, max: 10_000n, probability: 0.1},
        LARGE: {min: 14_000n, max: 20_000n, probability: 0.1},
    },
    POSITION_TYPES: {
        SAFE: {ltvRange: [0.3, 0.4], probability: 0.1},
        LIQUIDATABLE: {ltvRange: [0.62, 0.65], probability: 0.8},
        SEIZABLE: {ltvRange: [0.75, 0.85], probability: 0.1},
    },
    MODE: "chaos",
} as const;

async function main() {
    await network.provider.send("evm_mine", []);

    const liquidationContext = new LiquidationContext(CHAOS_CONFIG);
    await liquidationContext.doDeploy();

    await network.provider.send("evm_mine", []);

    // Create addresses.json
    fs.writeFileSync("./addresses.json", JSON.stringify(liquidationContext.jsonAddressData, null, 2));

    // Create addresses_liquidation.json
    const liquidationFilePath = path.join(process.cwd(), "addresses.json");
    fs.writeFileSync(liquidationFilePath, JSON.stringify(liquidationContext.jsonAddressData, null, 2));
    console.log(`addresses.json created at: ${liquidationFilePath}`);

    await liquidationContext.doDepositAndBorrow();
    console.info("\x1b[32m%s\x1b[0m", "Liquidation chaos context is setup !");
    await network.provider.send("evm_mine", []);

    await liquidationContext.setOraclesToMock();
    console.info("\x1b[32m%s\x1b[0m", "mockOracle OK");

    await network.provider.send("evm_setAutomine", [false]);
}
main();

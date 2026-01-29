import {network} from "hardhat";
import {LiquidationTestContext} from "../contexts";
import type {LiquidationTestData} from "../contexts";
import liquidationTestDataRaw from "./data/liquidation_test_data.json";
import {deployUSG} from "../actions/deployUSG";
import fs from "fs";
import {createJSONAddress} from "../contexts/BaseContext";
import readline from "node:readline";

async function confirmRun(message: string, func: () => Promise<void>): Promise<boolean> {
    return new Promise((resolve) => {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
        });
        rl.question(message, (answer: string) => {
            rl.close();
            if (answer.trim().toLowerCase() === "y") {
                resolve(true);
                func();
            } else {
                resolve(false);
            }
        });
    });
}

/**
 * Run liquidation test context with state-based execution
 *
 * Logic:
 * - init(): apply prices in state_0, then deploy all positions
 * - runState_1(): apply prices in state_1
 * - runState_2(): apply prices in state_2
 * - runState_3(): apply prices in state_3
 */
async function main() {
    const liquidationTestData = liquidationTestDataRaw as unknown as LiquidationTestData;
    // Mine a block to ensure we're on a fresh block
    await network.provider.send("evm_mine", []);

    // Create context
    const context = new LiquidationTestContext(liquidationTestData);
    const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deployUSG(context.maxUser);

    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext)));
    console.info("\x1b[32m%s\x1b[0m", "Contracts deployed and setup !");

    await context.init({baseContext});
<<<<<<< HEAD
    await network.provider.send("evm_mine", []);
    // ask the user if they want to run the test
    await confirmRun("press enter to run DUMP 1 ? (y/n)", async () => await context.runState_1());
    await network.provider.send("evm_mine", []);
    await confirmRun("press enter to run DUMP 2 ? (y/n)", async () => await context.runState_2());
    await network.provider.send("evm_mine", []);
    await confirmRun("press enter to run DUMP 3 ? (y/n)", async () => await context.runState_3());
    await network.provider.send("evm_mine", []);
=======

    // ask the user if they want to run the test
    await confirmRun("press enter to run DUMP 1 ? (y/n)", async () => await context.runState_1());
    await confirmRun("press enter to run DUMP 2 ? (y/n)", async () => await context.runState_2());
    await confirmRun("press enter to run DUMP 3 ? (y/n)", async () => await context.runState_3());
>>>>>>> eb73a52 (feat: liquidation test execution)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Script failed:", error);
        process.exit(1);
    });

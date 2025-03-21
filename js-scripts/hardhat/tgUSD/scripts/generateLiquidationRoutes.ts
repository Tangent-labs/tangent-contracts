import readline from "readline";
import {LiquidationRouteGeneration} from "../contexts/LiquidationRouteGeneration";
import path from "path";
import liquidationAddresses from "../../../../addresses-liquidation.json";

const svc = new LiquidationRouteGeneration();
svc.loadDynamicAssets(liquidationAddresses);

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

function stripDirname(filePath: string) {
    return path.relative(process.cwd(), filePath);
}

function askToContinue(step: string): Promise<boolean> {
    return new Promise((resolve) => {
        rl.question(`➡️  Continue ? (y/n): `, (answer) => {
            const normalized = answer.trim().toLowerCase();
            resolve(normalized === "y" || normalized === "");
        });
    });
}

async function main() {
    // Step 1: Validate CSV
    const {valid, mising} = svc.validateCsv();
    if (!valid) {
        console.error("-------------------------");
        console.error(' ❌ Some strings are not associated to an address \n See "js-scripts/hardhat/tgUSD/contexts/LiquidationRouteGeneration:liquidationAssets" \n');
        Array.from(mising).map((s) => console.log(` -> \x1b[38;5;214m${s}\x1b[0m`));
        console.error("-------------------------");
    } else {
        console.log("✅ csv is valid");
        console.log("Next step : Extract csv to a toute.json file");
    }

    if (!(await askToContinue("CSV validation"))) {
        rl.close();
        return;
    }

    // Step 2: Extract routes from CSV
    const routes = svc.loadRoutesFromCSV();
    svc.saveFile("routesRaw", routes);
    console.log(`✅ file ${stripDirname(svc.PATHS.routesRaw)} generated`);
    console.log(`Next step : Extract all the transfers from the routes`);

    if (!(await askToContinue("routes extraction"))) {
        rl.close();
        return;
    }

    // Step 3: Extract transfers
    const transfers = svc.processTransfers(routes);
    svc.saveFile("transfers", transfers);
    console.log(`✅ file ${stripDirname(svc.PATHS.transfers)} generated`);
    console.log(`Next step : Test all individual transfer in order  to get the good paramaters`);

    if (!(await askToContinue("transfer extraction"))) {
        rl.close();
        return;
    }

    // Step 4: Verify route steps
    const verifiedRoutes = await svc.testRouteSteps(transfers);
    svc.saveFile("verifiedRoutes", verifiedRoutes);

    if (verifiedRoutes.errors.length > 0) {
        console.error("❌ -------------------------");
        Array.from(verifiedRoutes.errors).map((s) => console.log(` -> \x1b[38;5;214m${s.route.display}\x1b[0m`));
        console.error("-------------------------");
    } else {
        console.log(`✅ file ${stripDirname(svc.PATHS.verifiedRoutes)} generated`);
        console.log(`Next step : Test complete routes`);
    }

    if (!(await askToContinue("route step verification"))) {
        rl.close();
        return;
    }

    // Step 5: Final test of routes
    const finalRoutes = await svc.testRoute(verifiedRoutes, transfers);
    svc.saveFile("finalRoutes", finalRoutes);
    console.log(`✅ file ${svc.PATHS.verifiedRoutes} generated`);

    rl.close();
}

main();

import readline from "readline";
import {LiquidationRouteGeneration, SingleSwap} from "../contexts/LiquidationRouteGeneration";
import path from "path";
import liquidationAddresses from "../../../../addresses.json";
const svc = new LiquidationRouteGeneration();
svc.loadDynamicAssets(liquidationAddresses);

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

function stripDirname(filePath: string) {
    return path.relative(process.cwd(), filePath);
}

main();

async function main() {
    // Step 1: Validate CSV
    const {csv, valid, missing} = await svc.validateCsv();

    if (!valid) {
        console.error("-------------------------");
        console.error(' ❌ Some strings are not associated to an address \n See "js-scripts/hardhat/tgUSD/contexts/LiquidationRouteGeneration:liquidationAssets" \n');
        Array.from(missing).map((s) => console.log(` -> \x1b[38;5;214m${s}\x1b[0m`));
        console.error("-------------------------");
    } else {
        console.log("✅ csv is valid");
        console.log("Next step : Extract csv to a route.json file");
    }

    // Step 2: Extract routes from CSV
    const routes = svc.loadRoutesFromCSV(csv);
    svc.saveFile("routesRaw", routes);
    console.log(`✅ file ${stripDirname(svc.PATHS.routesRaw)} generated`);
    console.log(`Next step : Extract all the transfers from the routes`);

    // Step 3: Extract transfers
    const singleSwaps = svc.formatSingleSwaps(routes);
    svc.saveFile("singleSwaps", singleSwaps);
    console.log(`✅ file ${stripDirname(svc.PATHS.singleSwaps)} generated`);
    console.log(`Next step : Test all individual transfer in order  to get the good paramaters`);

    // Step 4: Verify route steps
    const verifiedRoutes = await svc.testRouteSteps(singleSwaps);
    svc.saveFile("verifiedRoutes", verifiedRoutes);

    if (verifiedRoutes.errors.length > 0) {
        console.error("❌ -------------------------");
        console.log("OK route => ", verifiedRoutes.params.length, "errors => ", verifiedRoutes.errors.length);
        console.error("-------------------------");
    } else {
        console.log(`✅ file ${stripDirname(svc.PATHS.verifiedRoutes)} generated`);
        console.log(`Next step : Test complete routes`);
    }

    rl.close();
}

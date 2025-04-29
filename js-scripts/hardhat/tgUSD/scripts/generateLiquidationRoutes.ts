import readline from "readline";
import {LiquidationRouteGeneration, Transfer} from "../contexts/LiquidationRouteGeneration";
import path from "path";
import liquidationAddresses from "../../../../../addresses.json";
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

main();
//mainStepTargetTed();

async function mainStepTargetTed() {
    const transfers = [
        [
            {
                in: "0xdac17f958d2ee523a2206206994597c13d831ec7",
                pool: "0x7C4e143B23D72E6938E06291f705B5ae3D5c7c7C",
                out: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                display: "USDT >> USDT/USDC >> USDC ",
            } as Transfer,
        ],
    ];

    // [ 1,          0,          1,          1,          2        ],
    const verifiedRoutes = await svc.testRouteSteps(transfers);
    console.log(JSON.stringify(verifiedRoutes, null, 2));
}

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
        //Array.from(verifiedRoutes.errors).map((s) => console.log(` -> \x1b[38;5;214m${s.route.display}\x1b[0m`));
        console.log("OK route => ", verifiedRoutes.params.length, "errors => ", verifiedRoutes.errors.length);
        console.error("-------------------------");
    } else {
        console.log(`✅ file ${stripDirname(svc.PATHS.verifiedRoutes)} generated`);
        console.log(`Next step : Test complete routes`);
    }

    rl.close();
}

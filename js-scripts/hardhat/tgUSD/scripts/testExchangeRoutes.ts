import { LiquidationRouteGeneration, Transfer, VerifiedRoutes} from "../contexts/LiquidationRouteGeneration";
import {ethers} from "hardhat";
import fs from "fs";
import liquidationAddresses from "../../../../addresses-liquidation.json";
async function main() {
    console.log("Starting exchange route tests...");

    const liquidationRoute = new LiquidationRouteGeneration();
    liquidationRoute.loadDynamicAssets(liquidationAddresses);

    // Load dynamic assets first (assuming you have the addresses data)
    const [deployer] = await ethers.getSigners();
    console.log("Testing with account:", deployer.address);

    try {
        const finalRoutes = liquidationRoute.loadFile<VerifiedRoutes>("verifiedRoutes");
        const transfers = liquidationRoute.loadFile<Transfer[][]>("transfers");
        const results = await liquidationRoute.testRoute(finalRoutes,transfers);

        console.log("\n=== Exchange Test Summary ===");
        // console.log(`Total Routes: ${results.summary.totalRoutes}`);
        // console.log(`Successful: ${results.summary.successfulRoutes}`);
        // console.log(`Failed: ${results.summary.failedRoutes}`);

        console.log("\n=== Successful Routes ===> ", results.results.length);
        
        fs.writeFileSync( "./js-scripts/hardhat/tgUSD/data/successRoutes.json", JSON.stringify(results.results, null, 2));
        if (results.errors.length > 0) {
            console.log("\n=== Failed Routes ===");
            results.errors.forEach((error) => {
                //  console.log(`\nRoute: ${error.route}`);
                console.log("Error:", error.route,  error.error);
            });
            fs.writeFileSync( "./js-scripts/hardhat/tgUSD/data/failedRoutes.json", JSON.stringify(results.errors, null, 2));

        }
    } catch (error) {
        console.error("Error running exchange tests:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

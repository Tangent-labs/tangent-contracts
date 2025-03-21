import {FinalRoute, LiquidationRouteGeneration} from "../contexts/LiquidationRouteGeneration";
import {ethers} from "hardhat";
import liquidationAddresses from "../../../../addresses-liquidation.json";
async function main() {
    console.log("Starting exchange route tests...");

    const liquidationRoute = new LiquidationRouteGeneration();
    liquidationRoute.loadDynamicAssets(liquidationAddresses);

    // Load dynamic assets first (assuming you have the addresses data)
    const [deployer] = await ethers.getSigners();
    console.log("Testing with account:", deployer.address);

    try {
        const finalRoutes = liquidationRoute.loadFile<FinalRoute>("finalRoutes");
        const results = await liquidationRoute.testExchange(finalRoutes);

        console.log("\n=== Exchange Test Summary ===");
        console.log(`Total Routes: ${results.summary.totalRoutes}`);
        console.log(`Successful: ${results.summary.successfulRoutes}`);
        console.log(`Failed: ${results.summary.failedRoutes}`);

        console.log("\n=== Successful Routes ===");
        results.results.forEach((result) => {
            console.log(`\nRoute: ${result.route}`);
            // console.log("tgUSD Balance Change:", result.balanceChanges.tgUSD.difference);
            // console.log("Collateral Balance Change:", result.balanceChanges.collateral.difference);
        });

        if (results.errors.length > 0) {
            console.log("\n=== Failed Routes ===");
            results.errors.forEach((error) => {
                //  console.log(`\nRoute: ${error.route}`);
                console.log("Error:", error.error);
            });
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

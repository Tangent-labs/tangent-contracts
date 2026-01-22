import { CurveRouteService } from "./CurveRouteService";
import liquidationAddresses from "../../../../../addresses.json";
const svc = new CurveRouteService();
svc.loadDynamicAssets(liquidationAddresses);

main();

async function main() {
    // Step 1: Validate CSV
    const { csv, valid, missing } = await svc.validateCsv();

    if (!valid) {
        console.error("-------------------------");
        console.error(' ❌ Some strings are not associated to an address \n See "js-scripts/hardhat/USG/contexts/CurveRouteGeneration:liquidationAssets" \n');
        Array.from(missing).map((s) => console.log(` -> \x1b[38;5;214m${s}\x1b[0m`));
        console.error("-------------------------");
    } else {
        console.log("✅ CSV file is valid and verified");
    }
    console.log("-------------------------");
    // Step 2: Extract routes from CSV
    const rawRoutes = svc.loadRoutesFromCSV(csv);
    svc.saveFile("rawRoutes", rawRoutes);
    console.log("✅ " + rawRoutes.length + " complete routes extracted from CSV : Check in ./js-scripts/USG/routing/Curve/data/rawRoutes.json");

    console.log("-------------------------");
    // Step 3: Extract singleSwaps
    const singleSwaps = await svc.testRouteSteps(svc.formatSingleSwaps(rawRoutes));
    svc.saveFile("singleSwaps", singleSwaps);

    console.log("✅ " + "Single swaps deduced and tested from the complete routes : Check in ./js-scripts/USG/routing/Curve/data/singleSwaps.json");
    console.table([{ ["✅"]: singleSwaps.success.length, ["❌"]: singleSwaps.errors.length }]);

    // Step 4 : Hydrate routes with addresses
    const finalHydratedRoutes = svc.hydrateRawRoutes(rawRoutes, singleSwaps.success);
    svc.saveFile("finalRoutes", finalHydratedRoutes);

    console.log("-------------------------");
    console.log("✅ Final routes written : Check in ./js-scripts/USG/data/finalRoutes.json");
    console.table([{ ["✅"]: finalHydratedRoutes.success.length, ["❌"]: finalHydratedRoutes.errors.length }]);
}

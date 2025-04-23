import {LiquidationRouteGeneration} from "../contexts/LiquidationRouteGeneration";
import fs from "fs";
import liquidationAddresses from "../../../../../addresses.json";
async function main() {
    const action: "hydrate" | "create_template" = "hydrate";
    const templatePath = "./js-scripts/hardhat/tgUSD/data/tplRoute.json";
    const hydratedPath = "./js-scripts/hardhat/tgUSD/data/hydratedRoute.json";
    const sourcePath = "./js-scripts/hardhat/tgUSD/data/successRoutes.json";

    const liquidationRoute = new LiquidationRouteGeneration();
    liquidationRoute.loadDynamicAssets(liquidationAddresses);

    if (action === "hydrate") {
        const template = fs.readFileSync(templatePath, "utf-8");
        const routes = JSON.parse(template);
        const hydrated = liquidationRoute.hydrateRouteTemplate(routes);
        fs.writeFileSync(hydratedPath, JSON.stringify(hydrated, null, 2));
    }

    if (action === "create_template") {
        const source = fs.readFileSync(sourcePath, "utf-8");
        const routes = JSON.parse(source);
        const template = liquidationRoute.createRouteTemplate(routes);
        fs.writeFileSync(templatePath, JSON.stringify(template, null, 2));
    }

    const template = fs.readFileSync("./js-scripts/hardhat/tgUSD/data/tplRoute.json", "utf-8");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

import {liquidationAssets, CurveRouteGeneration, RouteParams, RouteResult} from "./CurveRouteGeneration";
import liquidationAddresses from "../../../../../addresses.json";
import {ZeroAddress} from "ethers";
const svc = new CurveRouteGeneration();
svc.loadDynamicAssets(liquidationAddresses);

main();

async function main() {
    const finalRoutes = svc.loadFile<{
        success: RouteResult[];
        errors: string[];
    }>("finalRoutes");
    const rawRoutes = svc.loadFile<RouteParams[]>("rawRoutes");

    const refreshedRoutes: RouteResult[] = [];

    // Iterate through rawRoutes and find associated route in finalRoutes
    rawRoutes.forEach((rawRoute) => {
        // Find associated route in finalRoutes
        const finalRoute = finalRoutes.success.find((r) => {
            return r.display === rawRoute.display;
        });

        // If we find a match, we can use the params from finalRoute to replace addresses
        if (finalRoute) {
            const routeAddresses = [];
            const singleSwaps = rawRoute.singleSwaps;

            for (let index = 0; index < singleSwaps.length; ++index) {
                const singleSwap = singleSwaps[index];
                if (index === 0) {
                    routeAddresses.push(liquidationAssets[singleSwap.in]);
                }
                routeAddresses.push(liquidationAssets[singleSwap.pool]);
                routeAddresses.push(liquidationAssets[singleSwap.out]);
            }

            while (routeAddresses.length < 11) {
                routeAddresses.push(ZeroAddress);
            }

            refreshedRoutes.push({
                display: rawRoute.display,
                in: liquidationAssets[rawRoute.in],
                out: liquidationAssets[rawRoute.out],
                params: {routeAddresses, swapParamsFull: finalRoute.params.swapParamsFull},
            });
        }
    });

    svc.saveFile("finalRoutes", {
        success: refreshedRoutes,
        errors: finalRoutes.errors,
    });
}

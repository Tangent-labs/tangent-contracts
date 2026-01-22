import { CurveRouteService, RouteParams, RouteResult, SwapParamsAndDisplay } from "./CurveRouteService";
import liquidationAddresses from "../../../../../addresses.json";
import { ZeroAddress } from "ethers";
import { LIQUIDATION_ASSETS } from "./config";
const svc = new CurveRouteService();
svc.loadDynamicAssets(liquidationAddresses);

main();

async function main() {
    const svc = new CurveRouteService();
    await svc.loadDynamicAssets(liquidationAddresses);
    const finalRoutes = svc.loadFile<{
        success: RouteResult;
        errors: string[];
    }>("finalRoutes");
    const rawRoutes = svc.loadFile<RouteParams[]>("rawRoutes");

    const refreshedRoutes: RouteResult = {};

    const successedRoutes = finalRoutes.success;

    // Iterate through rawRoutes and find associated route in finalRoutes
    rawRoutes.forEach((rawRoute) => {
        let swapParams: SwapParamsAndDisplay = null!;
        // Find associated route in finalRoutes
        Object.keys(successedRoutes).forEach((tokenInAddress) => {
            Object.entries(successedRoutes[tokenInAddress]).forEach(([tokenOutAddress, routes]) => {
                routes.forEach((route) => {
                    if (route.display === rawRoute.display) {
                        swapParams = route;
                    }
                });
            });
        });

        // If we find a match , we can use the params from finalRoute to replace addresses
        if (swapParams) {
            const routeAddresses = [];
            const singleSwaps = rawRoute.singleSwaps;

            for (let index = 0; index < singleSwaps.length; ++index) {
                const singleSwap = singleSwaps[index];
                if (index === 0) {
                    routeAddresses.push(LIQUIDATION_ASSETS[singleSwap.in]);
                }
                routeAddresses.push(LIQUIDATION_ASSETS[singleSwap.pool]);
                routeAddresses.push(LIQUIDATION_ASSETS[singleSwap.out]);
            }

            while (routeAddresses.length < 11) {
                routeAddresses.push(ZeroAddress);
            }

            const tokenInAddress = LIQUIDATION_ASSETS[rawRoute.in].toLocaleLowerCase();
            const tokenOutAddress = LIQUIDATION_ASSETS[rawRoute.out].toLocaleLowerCase();

            const paramsAndDisplay = {
                params: {
                    routeAddresses: routeAddresses,
                    swapParamsFull: swapParams.params.swapParamsFull,
                },
                display: swapParams.display,
            };

            if (refreshedRoutes[tokenInAddress]) {
                if (refreshedRoutes[tokenInAddress][tokenOutAddress]) {
                    refreshedRoutes[tokenInAddress][tokenOutAddress].push(paramsAndDisplay);
                } else {
                    refreshedRoutes[tokenInAddress][tokenOutAddress] = [paramsAndDisplay];
                }
            } else {
                refreshedRoutes[tokenInAddress] = { [tokenOutAddress]: [paramsAndDisplay] };
            }
        }
    });

    svc.saveFile("finalRoutes", {
        success: refreshedRoutes,
        errors: finalRoutes.errors,
    });
}

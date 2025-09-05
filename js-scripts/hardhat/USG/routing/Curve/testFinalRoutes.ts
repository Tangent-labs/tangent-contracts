import {CurveRouteGeneration, RouteResult, ThiefConfig} from "./CurveRouteGeneration";
import liquidationAddresses from "../../../../../addresses.json";
import {ethers} from "hardhat";
import {routers} from "@tangent/defi-resources";
import {AddressLike, ZeroAddress} from "ethers";
const svc = new CurveRouteGeneration();
svc.loadDynamicAssets(liquidationAddresses);

main();

const zapPools: AddressLike[] = [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress];

async function main() {
    const finalRoutes = svc.loadFile<{
        success: RouteResult[];
        errors: string[];
    }>("finalRoutes");

    const usr = (await ethers.getSigners())[7];
    // TODO Need to connect it to the markets to see how much
    const amount = "1";

    const errors: {display: string; error: string}[] = [];

    // Iterate through rawRoutes and find associated route in finalRoutes

    for (let index = 0; index < finalRoutes.success.length; index++) {
        const finalRoute = finalRoutes.success[index];
        const thiefData = ThiefConfig.find((a) => a.address.toLowerCase() === finalRoute.in.toLowerCase());

        const amountIn = ethers.parseUnits(amount, thiefData?.decimals || 18);
        await svc.prepareUserForExchange(finalRoute.in, finalRoute.display, usr, amount, thiefData);

        const router = await ethers.getContractAt("ICurveRouter", routers.CURVE_V1_2_ROUTER);

        let dy = 0n;
        try {
            //@ts-ignore
            dy = await router.get_dy(finalRoute.params.routeAddresses, finalRoute.params.swapParamsFull, amountIn, zapPools);
        } catch (e) {
            errors.push({
                display: finalRoute.display,
                error: e.message,
            });
            break;
        }
        try {
            //@ts-ignore
            await router
                //@ts-ignore
                .connect(usr)
                //@ts-ignore
                .exchange(finalRoute.params.routeAddresses, finalRoute.params.swapParamsFull, amountIn, dy - (dy * 1n) / 1000n, zapPools, await usr.getAddress());
        } catch (e) {
            errors.push({
                display: finalRoute.display,
                error: e.message,
            });
        }
    }

    svc.saveFile("finalRoutesTestRepport", errors);
}

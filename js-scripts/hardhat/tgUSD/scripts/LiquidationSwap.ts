import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import addressesLiquidation from "../../../../addresses.json";
import {swap} from "../actions/swapCurve";
import {ethers} from "hardhat";

async function main() {
    // const user = (await ethers.getSigners()).at(0);
    // //const swapAmount = 1_000_000;
    // const swapAmount = 50_000;
    // const promises = addressesLiquidation.markets.map((market) => {
    //     if (market.collatName !== "USDC_fxUSD") {
    //         return;
    //     }

    //     switch (market.marketType) {
    //         case "Convex_CRV":
    //         case "Convex_FXN":
    //             return swap(user!, market.collatAddress, 1, 0, swapAmount.toString());
    //         default:
    //             return;
    //     }
    // });
    // await Promise.all(promises.filter((p) => !!p));
    const day = 30;
    const seconds = day * 24 * 60 * 60;
    await time.increase(seconds);
    console.info("\x1b[32m%s\x1b[0m", "Time has been incresed by " + day + " day on the test node !");
}
main();

import * as contractAddresses from "../../../../addresses.json";
import {MainSetup} from "../../Main.setup";
import {executeUserMarketAction, prepareUserAmountByMarket} from "./common";

export async function borrow(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
    await executeUserMarketAction(mainSetup, userAmountByMarket, async (market, marketAddress, user, parsedAmount) => {
        await market.connect(user).borrow(user.address, parsedAmount);
    });
    console.info("\x1b[32m%s\x1b[0m", "All borrow actions completed across specified markets!");
}

export async function borrowAll() {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();
    const allMarkets = contractAddresses.markets;

    // Loop through all markets
    const userAmountByMarket = prepareUserAmountByMarket(mainSetup, allMarkets, "7000");

    // Call the borrow function for all markets
    await borrow(mainSetup, userAmountByMarket);
}

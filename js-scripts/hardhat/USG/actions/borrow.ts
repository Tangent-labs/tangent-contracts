import {MainSetup} from "../../Main.setup";
import {Market} from "../contexts/BaseContext";
import {executeUserMarketAction, prepareUserAmountByMarket} from "./common";

export async function borrow(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
    try {
        await executeUserMarketAction(mainSetup, userAmountByMarket, async (market, marketAddress, user, parsedAmount) => {
            await market.connect(user).borrow(user.address, parsedAmount);
        });
    } catch (error) {
        console.error("Error borrowing", userAmountByMarket, error);
    }
    console.info("\x1b[32m%s\x1b[0m", "All borrow actions completed across specified markets!");
}

export async function borrowAll(allMarkets: Market[]) {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();

    // Loop through all markets
    const userAmountByMarket = prepareUserAmountByMarket(mainSetup, allMarkets, "7000");

    // Call the borrow function for all markets
    try {
        await borrow(mainSetup, userAmountByMarket);
    } catch (error) {
        console.error("Error borrowing", userAmountByMarket, error);
    }
}

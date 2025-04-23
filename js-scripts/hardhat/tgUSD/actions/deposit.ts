import {ethers} from "hardhat";
import {MainSetup} from "../../Main.setup";
import {executeUserMarketAction, prepareUserAmountByMarket} from "./common";
import {Market} from "../contexts/BaseContext";

export async function deposit(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
    const collatTokenCache: Record<string, any> = {};
    // Loop through each market and perform deposit actions
    await executeUserMarketAction(mainSetup, userAmountByMarket, async (market, marketAddress, user, parsedAmount) => {
        let collatToken;
        if (collatTokenCache[marketAddress]) {
            collatToken = collatTokenCache[marketAddress];
        } else {
            collatToken = await ethers.getContractAt("ERC20", await market.collatToken());
            collatTokenCache[marketAddress] = collatToken;
        }
        await collatToken.connect(user).approve(market, ethers.MaxUint256);

        await market.connect(user).deposit(user.address, parsedAmount, true);
    });
    console.info("\x1b[32m%s\x1b[0m", "All deposit actions completed across specified markets!");
}

export async function depositAndBorrow(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
    const collatTokenCache: Record<string, any> = {};

    // Loop through each market and perform deposit actions
    await executeUserMarketAction(mainSetup, userAmountByMarket, async (market, marketAddress, user, parsedAmount) => {
        let collatToken;
        if (collatTokenCache[marketAddress]) {
            collatToken = collatTokenCache[marketAddress];
        } else {
            collatToken = await ethers.getContractAt("ERC20", await market.collatToken());
            collatTokenCache[marketAddress] = collatToken;
        }
        await collatToken.connect(user).approve(market, ethers.MaxUint256);
        await market.connect(user).depositAndBorrow(user.address, parsedAmount, true);
    });
    console.info("\x1b[32m%s\x1b[0m", "All deposit actions completed across specified markets!");
}

// Function to deposit to all markets
export async function depositAll(allMarkets: Market[]) {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();

    const userAmountByMarket = prepareUserAmountByMarket(mainSetup, allMarkets, "10000");
    await deposit(mainSetup, userAmountByMarket);
}

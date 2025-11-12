import {ethers} from "hardhat";
import {MainSetup} from "../../Main.setup";
import {Market} from "../contexts/BaseContext";
import {prepareUserAmountByMarket, loadAddresses} from "./common";
import {parseEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export async function borrow(users: HardhatEthersSigner[], userAmountByMarket: Record<string, Record<string, string>>) {
    try {
        const addresses = loadAddresses();
        const errorMessages = new Set<string>();
        const collatTokenCache: Record<string, any> = {};
        const errorMarkets = new Map<string, number>();
        for (const marketAddress of Object.keys(userAmountByMarket || {})) {
            const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
            const collatName = addresses?.markets?.find((m: any) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase())?.collatName;

            let i = -1;
            for (const user of users) {
                i++;
                const amount = userAmountByMarket?.[marketAddress]?.[user.address] || "0";
                let parsedAmount = parseEther(amount);
                //console.log("borrow", marketAddress, user.address, parsedAmount);

                if (parsedAmount > 0n) {
                    try {
                        let collatToken;
                        if (collatTokenCache[marketAddress]) {
                            collatToken = collatTokenCache[marketAddress];
                        } else {
                            collatToken = await ethers.getContractAt("ERC20", await market.collatToken());
                            collatTokenCache[marketAddress] = collatToken;
                        }

                        // Check maxBorrowable limit
                        // const marketAsCollateral = await ethers.getContractAt("ICollateral", marketAddress);
                        const maxBorrowableAmount = await market.maxBorrowable(user.address);
                        const positionValue = await market.positionValue(user.address);
                        //  console.log("maxBorrowableAmount", maxBorrowableAmount, positionValue);

                        // Skip if maxBorrowable is 0
                        if (maxBorrowableAmount === 0n) {
                            console.log(`Skipping borrow for user  ${i} ${collatName || "-"}  ${positionValue}- maxBorrowable is 0`);

                            continue;
                        }

                        await market.connect(user).borrow(user.address, parsedAmount);
                        //    console.log("borrowed", collatName || "-", i, parsedAmount);
                    } catch (e) {
                        const current = errorMarkets.get(marketAddress) || 0;
                        errorMarkets.set(marketAddress, current + 1);
                        errorMessages.add(`${(e as Error).message}`);
                        console.log("borrowed error", e.message || "-", i, parsedAmount);
                        //console.error(`error for deposit market : ${marketAddress} & user : ${user.address}`);
                        // throw e;
                    }
                }
            }
        }
        if (errorMessages.size) {
            errorMessages.forEach(console.log);
        }
        if (errorMarkets.size) {
            console.log("List of failed market borrow  : ");
            const addresses = loadAddresses();
            for (const [address, count] of errorMarkets) {
                console.log(addresses.markets.find((m: any) => m.marketAddress.toLowerCase() === address.toLowerCase())?.collatName, count);
            }
        }
        console.info("\x1b[32m%s\x1b[0m", "All borrow actions completed across specified markets!");
    } catch (e) {
        console.error(`general error for market borrow  `, (e as Error).message);
    }
}

// export async function borrow(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
//     let _marketAddress: string = "-";
//     try {
//         await executeUserMarketAction(mainSetup, userAmountByMarket, async (market, marketAddress, user, parsedAmount) => {
//             _marketAddress = marketAddress;
//             await market.connect(user).borrow(user.address, parsedAmount);
//         });
//     } catch (error) {
//         console.error("Error borrowing", _marketAddress, error);
//     }
//     console.info("\x1b[32m%s\x1b[0m", "All borrow actions completed across specified markets!");
// }

export async function borrowAll(allMarkets: Market[]) {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();

    // Loop through all markets
    const userAmountByMarket = prepareUserAmountByMarket(mainSetup, allMarkets, "7000");

    // Call the borrow function for all markets
    try {
        await borrow(mainSetup.users as HardhatEthersSigner[], userAmountByMarket);
    } catch (error) {
        console.error("Error borrowing", userAmountByMarket, error);
    }
}

import {ethers} from "hardhat";
import {MainSetup} from "../../Main.setup";
import {prepareUserAmountByMarket, loadAddresses} from "./common";
import {Market} from "../contexts/BaseContext";
import {parseEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export async function deposit(users: HardhatEthersSigner[], userAmountByMarket: Record<string, Record<string, string>>) {
    try {
        const addresses = loadAddresses();
        const collatTokenCache: Record<string, any> = {};
        const errorMarkets = new Map<string, number>();

        const errorMessages = new Set<string>();
        const okDeposit = new Map<string, number>();
        for (const marketAddress of Object.keys(userAmountByMarket || {})) {
            const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
            let i = -1;
            for (const user of users) {
                i++;
                const amount = userAmountByMarket?.[marketAddress]?.[user.address] || "0";

                const parsedAmount = parseEther(amount);
                const collatName = addresses?.markets?.find((m: any) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase())?.collatName;

                if (parsedAmount > 0n) {
                    try {
                        let collatToken;
                        if (collatTokenCache[marketAddress]) {
                            collatToken = collatTokenCache[marketAddress];
                        } else {
                            collatToken = await ethers.getContractAt("IERC20", await market.collatToken());
                            collatTokenCache[marketAddress] = collatToken;
                        }

                        const balance = await collatToken.balanceOf(user.address);
                        if (balance < parsedAmount) {
                            errorMessages.add(`${collatName} not   enough asset to deposit`);

                            continue;
                        }
                        await collatToken.connect(user).approve(market, 0n);
                        await collatToken.connect(user).approve(market, ethers.MaxUint256);

                        await market.connect(user).deposit(user.address, parsedAmount);

                        const positionValue = await market.positionValue(user.address);
                        const maxBorrowable = await market.maxBorrowable(user.address);
                        // console.log("deposited", collatName || "-", i, parsedAmount, positionValue, maxBorrowable);
                        const current = okDeposit.get(marketAddress) || 0;
                        okDeposit.set(marketAddress, current + 1);
                    } catch (e) {
                        const current = errorMarkets.get(marketAddress) || 0;
                        errorMarkets.set(marketAddress, current + 1);
                        console.log("deposited error", collatName || "-", i, parsedAmount);
                        errorMessages.add(`${collatName} ${e as Error}.message}`);
                        continue;
                    }
                }
            }
        }
        if (errorMessages.size) {
            for (const message of errorMessages) {
                console.log(message);
            }
        }

        if (errorMarkets.size) {
            console.log("List of failed markets deposit  : ");

            for (const [address, count] of errorMarkets) {
                console.log(addresses.markets.find((m: any) => m.marketAddress.toLowerCase() === address.toLowerCase())?.collatName, count);
            }
        }
        if (okDeposit.size) {
            console.log("List of OK markets deposit  : ");

            for (const [address, count] of okDeposit) {
                console.log(addresses.markets.find((m: any) => m.marketAddress.toLowerCase() === address.toLowerCase())?.collatName, count);
            }
        } else {
            console.log("No  OK markets deposit  : ");
        }
        console.info("\x1b[32m%s\x1b[0m", "All deposit actions completed across specified markets!");
    } catch (e) {
        console.error(`general error for market deposit  `, (e as Error).message);
    }
}

export async function depositAndBorrow(mainSetup: MainSetup, userAmountByMarket: Record<string, Record<string, string>>) {
    const collatTokenCache: Record<string, any> = {};

    try {
        const collatTokenCache: Record<string, any> = {};
        const errorMarkets = new Map<string, number>();
        for (const marketAddress of Object.keys(userAmountByMarket || {})) {
            const market = await ethers.getContractAt("BasicERC20Market", marketAddress);

            for (const user of mainSetup.users) {
                const amount = userAmountByMarket?.[marketAddress]?.[user.address] || "0";
                const parsedAmount = parseEther(amount);

                if (parsedAmount > 0n) {
                    try {
                        let collatToken;
                        if (collatTokenCache[marketAddress]) {
                            collatToken = collatTokenCache[marketAddress];
                        } else {
                            collatToken = await ethers.getContractAt("ERC20", await market.collatToken());
                            collatTokenCache[marketAddress] = collatToken;
                        }

                        const balance = await collatToken.balance(user.address);
                        if (balance < parsedAmount) {
                            console.log("Not enough asset to deposit");
                            continue;
                        }

                        await collatToken.connect(user).approve(market, 0n);
                        await collatToken.connect(user).approve(market, ethers.MaxUint256);
                        // For depositAndBorrow, we need to specify how much USG to borrow
                        // Using a default of 50% of the deposited amount as USG to borrow
                        const debtBorrow = parsedAmount / 3n;
                        await market.connect(user).depositAndBorrow(parsedAmount, debtBorrow);
                    } catch (e) {
                        const current = errorMarkets.get(marketAddress) || 0;
                        errorMarkets.set(marketAddress, current + 1);
                    }
                }
            }
        }
        if (errorMarkets.size) {
            console.log("List of failed markets deposit & borrow : ");
            const addresses = loadAddresses();
            for (const [address, count] of errorMarkets) {
                console.log(addresses.markets.find((m: any) => m.marketAddress.toLowerCase() === address.toLowerCase())?.collatName, count);
            }
        }
        console.info("\x1b[32m%s\x1b[0m", "All deposit actions completed across specified markets!");
    } catch (e) {
        console.error(`general error for market deposit  `, (e as Error).message);
    }

    // Loop through each market and perform deposit actions
}

// Function to deposit to all markets
export async function depositAll(allMarkets: Market[]) {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();

    const userAmountByMarket = prepareUserAmountByMarket(mainSetup, allMarkets, "10000");
    await deposit(mainSetup.users as HardhatEthersSigner[], userAmountByMarket);
}

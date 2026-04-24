import {parseEther} from "ethers";
import {MainSetup} from "../../Main.setup";
import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import * as fs from "fs";
import * as path from "path";

export type UserMarketParams = Record<string, Record<string, string>>;

export type AddressMarketEntry = {
    marketAddress: string;
    collatName?: string;
    marketName?: string;
};

export function getMarketLabel(addresses: {markets?: AddressMarketEntry[]} | null | undefined, marketAddress: string): string {
    const market = (addresses?.markets || []).find((m) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase());
    return market?.collatName || market?.marketName || marketAddress;
}

/**
 * Dynamically loads addresses.json from the project root.
 * This function reads the file fresh each time it's called,
 * so changes to the file will be reflected immediately.
 */
export function loadAddresses(): any {
    const addressesPath = path.resolve(process.cwd(), "addresses.json");
    const addressesData = fs.readFileSync(addressesPath, "utf8");
    return JSON.parse(addressesData);
}

export async function executeUserMarketAction(
    mainSetup: MainSetup,
    userAmountByMarket: UserMarketParams,
    actionFn: (market: any, marketAddress: string, user: HardhatEthersSigner, parsedAmount: bigint) => Promise<void>
) {
    for (const marketAddress of Object.keys(userAmountByMarket || {})) {
        const market = await ethers.getContractAt("BasicERC20Market", marketAddress);

        for (const user of mainSetup.users) {
            const amount = userAmountByMarket?.[marketAddress]?.[user.address] || "0";
            const parsedAmount = parseEther(amount);

            if (parsedAmount > 0n) {
                try {
                    await actionFn(market, marketAddress, user, parsedAmount);
                } catch (e) {
                    console.error(`error for market : ${marketAddress} & user : ${user.address}`);
                    // throw e;
                }
            }
        }
    }
}

export function prepareUserAmountByMarket(mainSetup: MainSetup, allMarkets: {marketAddress: string}[], amountPerUser: string): Record<string, Record<string, string>> {
    const userAmountByMarket: UserMarketParams = {};

    for (const {marketAddress} of allMarkets) {
        userAmountByMarket[marketAddress] = {};

        for (const user of mainSetup.users) {
            userAmountByMarket[marketAddress][user.address] = amountPerUser;
        }
    }

    return userAmountByMarket;
}

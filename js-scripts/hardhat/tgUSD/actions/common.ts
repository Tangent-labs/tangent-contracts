import {parseEther} from "ethers";
import {MainSetup} from "../../Main.setup";
import {ethers} from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export async function executeUserMarketAction(
    mainSetup: MainSetup,
    userAmountByMarket: Record<string, Record<string, string>>,
    actionFn: (market: any, marketAddress: string, user: HardhatEthersSigner, parsedAmount: bigint) => Promise<void>
) {
    for (const marketAddress of Object.keys(userAmountByMarket || {})) {
        const market = await ethers.getContractAt("MarketNoSociabilization", marketAddress);

        for (const user of mainSetup.users) {
            const amount = userAmountByMarket?.[marketAddress]?.[user.address] || "0";
            const parsedAmount = parseEther(amount);

            if (parsedAmount > 0n) {
                try {
                    await actionFn(market, marketAddress, user, parsedAmount);
                } catch (e) {
                    console.error(`error for market : ${marketAddress} & user : ${user.address}`);
                    throw e;
                }
            }
        }
    }
}

export function prepareUserAmountByMarket(mainSetup: MainSetup, allMarkets: {marketAddress: string}[], amountPerUser: string): Record<string, Record<string, string>> {
    const userAmountByMarket: Record<string, Record<string, string>> = {};

    for (const {marketAddress} of allMarkets) {
        userAmountByMarket[marketAddress] = {};

        for (const user of mainSetup.users) {
            userAmountByMarket[marketAddress][user.address] = amountPerUser;
        }
    }

    return userAmountByMarket;
}

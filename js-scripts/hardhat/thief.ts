import {setStorageAt} from "@nomicfoundation/hardhat-network-helpers";
import {GlobalHelper} from "./GlobalHelper";

import {parseUnits, Signer} from "ethers";

export interface TokenAmounts {
    slotBalance: number;
    decimals: number;
    address: string;
    isVyper: boolean;
    amount: number;
}
// tokens used must be in the TOKEN config to be able to retrieve the slot of the balanceMapping
export async function giveTokensToAddresses(users: Signer[], tokensAmounts: TokenAmounts[]) {
    for (let i = 0; i < users.length; i++) {
        const userAddress = await users[i].getAddress();
        for (let j = 0; j < tokensAmounts.length; j++) {
            const tokenAmount = tokensAmounts[j];
            let storageSlot = "";
            if (tokenAmount.isVyper) {
                storageSlot = GlobalHelper.calculateStorageSlotEthersVyper(userAddress, tokenAmount.slotBalance);
            } else if (tokenAmount.address === "0x66a1e37c9b0eaddca17d3662d6c05f4decf3e110") {
                storageSlot = GlobalHelper.calculateERC20OZUpgradeable(userAddress);
            } else {
                storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(userAddress, tokenAmount.slotBalance);
            }
            await setStorageAt(tokenAmount.address, storageSlot, parseUnits(tokenAmount.amount.toString(), tokenAmount.decimals));
        }
    }
}

export async function giveTokensoAddresss(user: Signer, address: string, amount: bigint, slotBalance: number, isVyper: boolean) {
    const userAddress = await user.getAddress();
    const UpgradableAddres = ["0x15700b564ca08d9439c58ca5053166e8317aa138", "0x66a1e37c9b0eaddca17d3662d6c05f4decf3e110"]
    let storageSlot = "";
    if (isVyper) {
        storageSlot = GlobalHelper.calculateStorageSlotEthersVyper(userAddress, slotBalance);
    } else if (UpgradableAddres.includes(address)) {
        storageSlot = GlobalHelper.calculateERC20OZUpgradeable(userAddress);
    } else {
        storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(userAddress, slotBalance);
    }

    await setStorageAt(address, storageSlot, amount);
}

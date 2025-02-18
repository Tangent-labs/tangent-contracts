import {setStorageAt} from "@nomicfoundation/hardhat-network-helpers";
import {GlobalHelper} from "./GlobalHelper";
import {ethers} from "hardhat";
import {parseUnits, Signer, toQuantity} from "ethers";

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
            } else {
                storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(userAddress, tokenAmount.slotBalance);
            }
            await setStorageAt(tokenAmount.address, storageSlot, parseUnits(tokenAmount.amount.toString(), tokenAmount.decimals));
        }
    }
}

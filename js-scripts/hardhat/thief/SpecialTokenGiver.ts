import { setStorageAt } from "@nomicfoundation/hardhat-network-helpers";
import { COMMON_ERC20S } from "@tangent/defi-resources";
import { ethers } from "hardhat";
import { GlobalHelper } from "../GlobalHelper";

interface SpecialTokenGiverImplementation {
    token: string;
    giveToken(amount: bigint, addresses: string[]): Promise<void>;
}

function normalizeAddress(address: string) {
    return address.toLowerCase();
}

async function setUint256At(token: string, slot: string | number, value: bigint) {
    await setStorageAt(token, slot, ethers.zeroPadValue(ethers.toBeHex(value), 32));
}

async function increaseRawSlot(token: string, slot: number, amount: bigint) {
    const current = BigInt(await ethers.provider.getStorage(token, slot));
    await setUint256At(token, slot, current + amount);
}

async function getMappingValue(token: string, account: string, mappingSlot: number) {
    const storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(account, mappingSlot);
    return BigInt(await ethers.provider.getStorage(token, storageSlot));
}

async function setMappingValue(token: string, account: string, mappingSlot: number, value: bigint) {
    const storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(account, mappingSlot);
    await setUint256At(token, storageSlot, value);
}

class OUSDTokenGiver implements SpecialTokenGiverImplementation {
    token = COMMON_ERC20S.OUSD;
    private totalSupplySlot = 154;
    private creditBalancesSlot = 157;
    private nonRebasingSupplySlot = 160;
    private alternativeCreditsPerTokenSlot = 161;
    private rebaseStateSlot = 162;
    private stdNonRebasing = 1n;
    private nonRebasingCreditsPerToken = ethers.parseEther("1");

    async giveToken(amount: bigint, addresses: string[]) {
        let totalDelta = 0n;

        for (const address of addresses) {
            const currentBalance = await getMappingValue(this.token, address, this.creditBalancesSlot);
            if (currentBalance >= amount) {
                continue;
            }

            const delta = amount - currentBalance;
            totalDelta += delta;

            await setMappingValue(this.token, address, this.creditBalancesSlot, amount);
            await setMappingValue(this.token, address, this.alternativeCreditsPerTokenSlot, this.nonRebasingCreditsPerToken);
            await setMappingValue(this.token, address, this.rebaseStateSlot, this.stdNonRebasing);
        }

        if (totalDelta > 0n) {
            await increaseRawSlot(this.token, this.totalSupplySlot, totalDelta);
            await increaseRawSlot(this.token, this.nonRebasingSupplySlot, totalDelta);
        }
    }
}

export class SpecialTokenGiver {
    private static registry = new Map<string, SpecialTokenGiverImplementation>();

    static {
        this.register(new OUSDTokenGiver());
    }

    static register(implementation: SpecialTokenGiverImplementation) {
        this.registry.set(normalizeAddress(implementation.token), implementation);
    }

    static supports(token: string) {
        return this.registry.has(normalizeAddress(token));
    }

    static assertSupported(token: string) {
        if (!this.supports(token)) {
            throw new Error(`No special token giver registered for ${token}`);
        }
    }

    static async giveToken(token: string, amount: bigint, addresses: string[]) {
        this.assertSupported(token);
        await this.registry.get(normalizeAddress(token))!.giveToken(amount, addresses);
    }
}

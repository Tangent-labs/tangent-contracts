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

// Generic giver for the Origin rebasing tokens (OUSD / OETH).
// OETH is `contract OETH is OUSD {}` (it only overrides name/symbol/decimals), so both
// share the exact same storage layout and the slots below are valid for the two of them.
class RebaseTokenGiver implements SpecialTokenGiverImplementation {
    token: string;

    private totalSupplySlot = 154;
    private creditBalancesSlot = 157;
    private rebasingCreditsSlot = 158;
    private nonRebasingSupplySlot = 160;
    private alternativeCreditsPerTokenSlot = 161;
    private rebaseStateSlot = 162;

    // RebaseOptions enum: 0 = NotSet, 1 = StdNonRebasing, 2 = StdRebasing, 3/4 = yield delegation
    private stdNonRebasing = 1n;
    private nonRebasingCreditsPerToken = ethers.parseEther("1");

    constructor(token: string) {
        this.token = token;
    }

    async giveToken(amount: bigint, addresses: string[]) {
        const erc20 = await ethers.getContractAt("IERC20Metadata", this.token);

        let totalSupplyDelta = 0n;
        let nonRebasingSupplyDelta = 0n;
        let rebasingCreditsDelta = 0n;

        for (const address of addresses) {
            const rebaseState = await getMappingValue(this.token, address, this.rebaseStateSlot);
            if (rebaseState > this.stdNonRebasing + 1n) {
                throw new Error(`${address} is a yield delegation account on ${this.token}, cannot force its balance`);
            }

            // balanceOf != creditBalances as soon as the account is rebasing, so we ask the token itself
            const currentBalance = await erc20.balanceOf(address);
            if (currentBalance >= amount) {
                continue;
            }

            const currentCredits = await getMappingValue(this.token, address, this.creditBalancesSlot);
            const wasRebasing = (await getMappingValue(this.token, address, this.alternativeCreditsPerTokenSlot)) === 0n;

            // The account becomes non rebasing with 1e18 credits per token, so credits == balance
            await setMappingValue(this.token, address, this.creditBalancesSlot, amount);
            await setMappingValue(this.token, address, this.alternativeCreditsPerTokenSlot, this.nonRebasingCreditsPerToken);
            await setMappingValue(this.token, address, this.rebaseStateSlot, this.stdNonRebasing);

            totalSupplyDelta += amount - currentBalance;
            if (wasRebasing) {
                // Whole balance moves from the rebasing side to the non rebasing side
                nonRebasingSupplyDelta += amount;
                rebasingCreditsDelta -= currentCredits;
            } else {
                nonRebasingSupplyDelta += amount - currentBalance;
            }
        }

        if (totalSupplyDelta > 0n) {
            await increaseRawSlot(this.token, this.totalSupplySlot, totalSupplyDelta);
        }
        if (nonRebasingSupplyDelta > 0n) {
            await increaseRawSlot(this.token, this.nonRebasingSupplySlot, nonRebasingSupplyDelta);
        }
        if (rebasingCreditsDelta !== 0n) {
            await increaseRawSlot(this.token, this.rebasingCreditsSlot, rebasingCreditsDelta);
        }
    }
}

export class SpecialTokenGiver {
    private static registry = new Map<string, SpecialTokenGiverImplementation>();

    static {
        this.register(new RebaseTokenGiver(COMMON_ERC20S.OUSD));
        this.register(new RebaseTokenGiver(COMMON_ERC20S.OETH));
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
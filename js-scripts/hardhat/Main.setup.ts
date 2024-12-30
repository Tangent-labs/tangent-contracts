import {giveTokensToAddresses} from "./thief";
import {ethers} from "hardhat";

import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {TOKENS_TO_GIVE} from "./tokensToGive.config";

export class MainSetup {
    users: HardhatEthersSigner[] = [];

    erc20Minted = 1_000_000_000;

    constructor() {}

    async setupTestUsers() {
        this.users = (await ethers.getSigners()).slice(0, 5);
    }

    async giveTokens(
        users: HardhatEthersSigner[],
        extraTokens: {
            isVyper: boolean;
            slotBalance: number;
            address: string;
            decimals: number;
            amount: number;
        }[]
    ) {
        await giveTokensToAddresses(users, TOKENS_TO_GIVE(this.erc20Minted).concat(extraTokens));
    }
}

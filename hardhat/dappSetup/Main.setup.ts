import {giveTokensToAddresses, TokenAmounts} from "../thief";
import {ethers} from "hardhat";

import {thiefConfig, commonERC20, stakeDaoContracts, stakeDaoERC20, stakeDaoMapping} from "convergence-defi-tools";
import {sdCRV} from "convergence-defi-tools/ressources/erc20/stakeDao";
import {ZeroAddress} from "ethers";
import {HardhatEthersHelpers} from "hardhat/types";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {TOKENS_TO_GIVE} from "./tokensToGive.config";

export class MainSetup {
    users: HardhatEthersSigner[] = [];

    erc20Minted = ethers.parseEther("100000000");

    constructor() {}

    async setupTestUsers() {
        this.users = (await ethers.getSigners()).slice(0, 5);
    }

    async giveTokens(users: HardhatEthersSigner[]) {
        await giveTokensToAddresses(users, TOKENS_TO_GIVE(this.erc20Minted));
    }
}

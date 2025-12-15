import { giveTokensToAddresses } from "./thief/thief";
import { ethers } from "hardhat";

import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { commonERC20 } from "@tangent/defi-resources";
import { MaxUint256 } from "ethers";
import { TOKENS_TO_GIVE_WITH_LP } from "./thief/tokensToGiveWithLP";
import { TOKENS_TO_GIVE_WITHOUT_LP } from "./thief/tokensToGiveWithoutLP";

export class MainSetup {
    users: HardhatEthersSigner[] = [];
    userCount: number;
    erc20Minted = 1_000_000_000;

    constructor(userCount?: number) {
        this.userCount = userCount || 5;
    }

    async setupTestUsers() {
        this.users = (await ethers.getSigners()).slice(0, this.userCount);
    }

    async giveTokens(
        users: HardhatEthersSigner[],
        extraTokens: {
            isVyper: boolean;
            slotBalance: number;
            address: string;
            decimals: number;
            name: string
            amount: number;
        }[]
    ) {
        await giveTokensToAddresses(users, TOKENS_TO_GIVE_WITHOUT_LP(this.erc20Minted).concat(extraTokens));
        const erc4626 = [
            // {saving: commonERC20.sfrxUSD, stable: commonERC20.frxUSD},
            // {saving: commonERC20.wstUSR, stable: "0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4"},
            { saving: commonERC20.sDOLA, stable: commonERC20.DOLA },
            { saving: commonERC20.sUSDe, stable: commonERC20.USDe },
            { saving: commonERC20.scrvUSD, stable: commonERC20.crvUSD },
        ];
        await this.stakeInERC2646(erc4626, users);
    }

    async stakeInERC2646(
        erc4626s: {
            saving: string;
            stable: string;
        }[],
        users: HardhatEthersSigner[]
    ) {
        for (let index = 0; index < users.length; index++) {
            const user = users[index];

            for (let index = 0; index < erc4626s.length; index++) {
                const stable = await ethers.getContractAt("IERC20", erc4626s[index].stable);
                const saving = await ethers.getContractAt("IERC4626", erc4626s[index].saving);
                await stable.connect(user).approve(saving, MaxUint256);

                await saving.connect(user).deposit(ethers.parseEther("1000000"), user);
            }
        }
    }
}

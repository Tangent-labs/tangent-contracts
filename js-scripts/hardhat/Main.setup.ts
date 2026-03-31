import { giveTokensToAddresses } from "./thief/thief";
import { ethers } from "hardhat";

import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { COMMON_ERC20S } from "@tangent/defi-resources";
import { MaxUint256, parseEther } from "ethers";
import { TOKENS_TO_GIVE_WITH_LP } from "./thief/tokensToGiveWithLP";
import { TOKENS_TO_GIVE_WITHOUT_LP } from "./thief/tokensToGiveWithoutLP";
import { impersonateAccount, setBalance, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PROD_ADDRESSES } from "../../ignition/prod_addresses";

export class MainSetup {
    users: HardhatEthersSigner[] = [];
    userCount: number;
    erc20Minted = 1_000_000_000;

    constructor(userCount?: number) {
        this.userCount = userCount || 5;
    }

    async setupTestUsers() {
        this.users = (await ethers.getSigners()).slice(0, this.userCount);
        this.users[0] = await ethers.getSigner(PROD_ADDRESSES.DAO)
        if (this.users.length > 20) {
            for (let i = 19; i < this.users.length; i++) {
                const user = this.users[i];
                const userAddress = await user.getAddress();
                await setBalance(userAddress, parseEther("1000000000000000000000"));
            }
        }

        await setBalance(await this.users[0].getAddress(), parseEther("1000000000000000000000"));
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
        await giveTokensToAddresses(users, TOKENS_TO_GIVE_WITHOUT_LP(this.erc20Minted).concat(extraTokens));
        const erc4626 = [
            // {saving: COMMON_ERC20S.sfrxUSD, stable: COMMON_ERC20S.frxUSD},
            // {saving: COMMON_ERC20S.wstUSR, stable: "0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4"},
            { saving: COMMON_ERC20S.sDOLA, stable: COMMON_ERC20S.DOLA },
            { saving: COMMON_ERC20S.sUSDe, stable: COMMON_ERC20S.USDe },
            { saving: COMMON_ERC20S.scrvUSD, stable: COMMON_ERC20S.crvUSD },
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
                await impersonateAccount(await user.getAddress())
                await stable.connect(user).approve(saving, MaxUint256);

                await saving.connect(user).deposit(ethers.parseEther("1000000"), user);

                await stopImpersonatingAccount(await user.getAddress())

            }
        }
    }
}

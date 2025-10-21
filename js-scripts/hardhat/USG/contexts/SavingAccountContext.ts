import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {sendRewardSavingAccount} from "../actions/savingAccountAction";
import {ethers} from "hardhat";
import fs from "fs";
import {parseEther} from "ethers";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {IYearnV3Vault} from "../../../../typechain-types";
import path from "path";

export class SavingAccountContext {
    userCount: number = 1;
    user?: HardhatEthersSigner;

    async doDeploy() {
        const addresses = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../../../addresses.json"), "utf8"));

        const sTANAddress = addresses.tokens.sTAN;
        const sUSGAddress = addresses.tokens.sUSG;
        console.log(sTANAddress, sUSGAddress, addresses);

        const sTAN = await ethers.getContractAt("IYearnV3Vault", addresses.tokens.sTAN);
        const sUSG = await ethers.getContractAt("IYearnV3Vault", addresses.tokens.sUSG);
        this.user = (await ethers.getSigners())[0];
        if (!sTAN || !sUSG) {
            throw new Error("Deploy must be done : npm run deploy:usg-local");
        }

        await this.savingAccountRewards(sTAN, sUSG);
    }

    async savingAccountRewards(sTAN: IYearnV3Vault, sUSG: IYearnV3Vault) {
        const [sTANAddress, sUSGAddress] = await Promise.all([sTAN.getAddress(), sUSG.getAddress()]);

        await sendRewardSavingAccount(sTANAddress, this.user!, parseEther("10000"));
        await sendRewardSavingAccount(sUSGAddress, this.user!, parseEther("10000"));
        await sTAN.connect(this.user).process_report(sTANAddress);
        await sUSG.connect(this.user).process_report(sUSGAddress);

        await time.increase(2 * 60 * 60);
        await sendRewardSavingAccount(sUSGAddress, this.user!, parseEther("10000"));
        await sUSG.connect(this.user).process_report(sUSGAddress);
    }
}

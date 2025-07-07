import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const withdrawStakeDao = async (address: string, user: HardhatEthersSigner, amount: bigint) => {
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", address);
    await stakeVault.connect(user).withdraw(amount);
};

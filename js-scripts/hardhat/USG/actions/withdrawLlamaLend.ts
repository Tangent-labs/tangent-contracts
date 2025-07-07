import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const withdrawLlamaLend = async (vaultAddress: string, user: HardhatEthersSigner, amountToWithdraw: bigint) => {
    const vault = await ethers.getContractAt("ILlamaVault", vaultAddress);

    await vault.connect(user)["withdraw(uint256)"](amountToWithdraw);
};

import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

type LlamaKey = keyof typeof CURVE_CONTEXT;

export const withdrawLlamaLend = async (key: LlamaKey, user: HardhatEthersSigner, amountToWithdraw: bigint) => {
    const context = CURVE_CONTEXT[key];
    const vault = await ethers.getContractAt("ILlamaVault", context.stakeDaoVault);
    await vault.connect(user)["withdraw(uint256)"](amountToWithdraw);
};

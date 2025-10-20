import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const depositSavingAccount = async (contractAddress: string, user: HardhatEthersSigner, amount: bigint) => {
    const contract = await ethers.getContractAt("IYearnV3Vault", contractAddress);
    const tokenAddress = await contract.asset();
    const token = await ethers.getContractAt("IERC20", tokenAddress);

    await token.connect(user).approve(contractAddress, amount);
    await contract.connect(user).deposit(amount, await user.getAddress());
};

export const sendRewardSavingAccount = async (contractAddress: string, user: HardhatEthersSigner, amount: bigint) => {
    const contract = await ethers.getContractAt("IYearnV3Vault", contractAddress);
    const tokenAddress = await contract.asset();
    const token = await ethers.getContractAt("IERC20", tokenAddress);
    await token.connect(user).approve(contractAddress, amount);
    await token.connect(user).transferFrom(user, contractAddress, amount);
};

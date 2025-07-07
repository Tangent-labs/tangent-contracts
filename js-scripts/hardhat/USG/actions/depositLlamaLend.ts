import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";

export const depositLlamaLend = async (vaultAddress: string, tokenAddress: string, user: HardhatEthersSigner, tokenToGive: number, amountToDeposit: bigint) => {
    const vault = await ethers.getContractAt("ILlamaVault", vaultAddress);
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress);

    await giveTokensToAddresses([user], TOKENS_TO_GIVE(tokenToGive));

    await erc20.connect(user).approve(vault, MaxUint256);
    await vault.connect(user)["deposit(uint256)"](amountToDeposit);
};

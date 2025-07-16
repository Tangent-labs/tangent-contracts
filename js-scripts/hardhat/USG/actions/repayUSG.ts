import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ethers} from "hardhat";

export const repayUSG = async (marketAddress: string, user: HardhatEthersSigner, repayAmount: bigint) => {
    const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
    const userAddress = await user.getAddress();
    await market.connect(user).repay(userAddress, repayAmount);
};

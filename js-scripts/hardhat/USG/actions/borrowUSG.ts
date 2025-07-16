import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ethers} from "hardhat";

export const borrowUSG = async (marketAddress: string, user: HardhatEthersSigner, borrowAmount: bigint) => {
    const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
    const userAddress = await user.getAddress();
    await market.connect(user).borrow(userAddress, borrowAmount);
};

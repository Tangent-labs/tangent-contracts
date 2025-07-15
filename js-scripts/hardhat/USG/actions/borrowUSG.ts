import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MaxUint256} from "ethers";
import {ethers} from "hardhat";

export const borrowUSG = async (marketAddress: string, user: HardhatEthersSigner, borrowAmount: bigint) => {
    const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
    const userAddress = await user.getAddress();
    const collatAddress = await market.collatToken();
    const collatContract = await ethers.getContractAt("IERC20", collatAddress);
    await collatContract.connect(user).approve(market, MaxUint256);
    await market.connect(user).borrow(userAddress, borrowAmount);
};

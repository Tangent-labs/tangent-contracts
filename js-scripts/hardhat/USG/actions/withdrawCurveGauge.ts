import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const withdrawCurveGauge = async (address: string, user: HardhatEthersSigner, amount: bigint) => {
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", address);
    gauge.connect(user)["withdraw(uint256)"](amount);
};

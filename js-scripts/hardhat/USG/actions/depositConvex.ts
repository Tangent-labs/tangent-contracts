import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {ICurveStableSwapNG} from "../../../../typechain-types/src/interfaces/externals/Curve/ICurveStableSwapNG";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const depositConvex = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, pid: number, amount: bigint) => {
    const booster = await ethers.getContractAt("ICvxBooster", address);
    await lp.connect(user).approve(address, MaxUint256);
    await booster.connect(user).deposit(pid, amount, true);
};

import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ICurveStableSwapNG} from "../../../../typechain-types/src/interfaces/externals/Curve/ICurveStableSwapNG";
import {MaxUint256} from "ethers";

export const depositStakeDao = async (lp: ICurveStableSwapNG, address: string, user: HardhatEthersSigner, amount: bigint) => {
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", address);
    await lp.connect(user).approve(stakeVault, MaxUint256);
    await stakeVault.connect(user).deposit(user, amount, false);
};

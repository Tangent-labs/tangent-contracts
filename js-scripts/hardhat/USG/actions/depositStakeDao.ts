import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MaxUint256} from "ethers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const depositStakeDao = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", context.stakeDaoVault);
    await lp.connect(user).approve(stakeVault, MaxUint256);
    await stakeVault.connect(user).deposit(user, amount, true);
};

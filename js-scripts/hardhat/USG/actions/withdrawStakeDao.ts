import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const withdrawStakeDao = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", context.stakeDaoVault);
    await stakeVault.connect(user).withdraw(amount);
};

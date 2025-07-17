import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const withdrawConvex = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];
    const rewardsContract = await ethers.getContractAt("ICvxRewardToken", context.convexRewardToken);
    await rewardsContract.connect(user).withdrawAndUnwrap(amount, true);
};

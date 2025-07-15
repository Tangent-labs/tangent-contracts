import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

type ConvexKey = keyof typeof CURVE_CONTEXT;

export const withdrawConvex = async (lpKey: ConvexKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];

    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const rewardsContract = await ethers.getContractAt("ICvxRewardToken", context.convexRewardToken);

    await lp.connect(user).approve(rewardsContract, MaxUint256);
    await rewardsContract.connect(user).withdrawAndUnwrap(amount, true);
};

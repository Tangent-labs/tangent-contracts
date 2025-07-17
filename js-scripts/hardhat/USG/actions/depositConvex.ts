import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const depositConvex = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];

    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const booster = await ethers.getContractAt("ICvxBooster", "0xF403C135812408BFbE8713b5A23a04b3D48AAE31");

    await lp.connect(user).approve(booster, MaxUint256);
    await booster.connect(user).deposit(context.convexPID, amount, true);
};

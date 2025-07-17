import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MaxUint256} from "ethers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const depositCurveGauge = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];

    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", context.curveGauge);

    await lp.connect(user).approve(gauge, MaxUint256);
    gauge.connect(user)["deposit(uint256)"](amount);
};

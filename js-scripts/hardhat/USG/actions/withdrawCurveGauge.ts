import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

type CurveGaugeKey = keyof typeof CURVE_CONTEXT;

export const withdrawCurveGauge = async (lpKey: CurveGaugeKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];

    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", context.curveGauge);
    gauge.connect(user)["withdraw(uint256)"](amount);
};

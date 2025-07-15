import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const withdrawLlamaLend = async (key: CurveLpKey, user: HardhatEthersSigner, amountToWithdraw: bigint) => {
    const context = CURVE_CONTEXT[key];
    const vault = await ethers.getContractAt("ILlamaVault", context.curveLp);
    await vault.connect(user)["withdraw(uint256)"](amountToWithdraw);
};

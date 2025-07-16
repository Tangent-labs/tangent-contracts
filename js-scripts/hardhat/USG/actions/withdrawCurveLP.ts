import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const withdrawCurveLP = async (lpKey: CurveLpKey, amount: bigint, user: HardhatEthersSigner) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);

    try {
        await lp.connect(user)["remove_liquidity(uint256,uint256[])"](amount, [0n, 0n]);
    } catch (err) {
        try {
            await lp.connect(user)["remove_liquidity(uint256,uint256[2],address)"](amount, [0n, 0n], user);
        } catch (signatureError) {
            throw new Error(`Failed to remove liquidity with both signatures: ${signatureError}`);
        }
    }

    return lp;
};

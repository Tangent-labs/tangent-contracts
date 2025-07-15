import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

export type CurveLpKey = keyof typeof CURVE_CONTEXT;

/**
 * Deposit Curve LP tokens using a numerical amount.
 * @param lpKey The Curve LP key
 * @param user The signer/user
 * @param amount The amount to deposit, as a number (will be converted to bigint)
 */
export const depositCurveLP = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);

    console.log("context.curveLp : ", context.curveLp);

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0 = await ethers.getContractAt("ERC20", coin0Address);
    const coin1 = await ethers.getContractAt("ERC20", coin1Address);

    const [decimals0, decimals1] = await Promise.all([coin0.decimals(), coin1.decimals()]);

    const amount0 = BigInt(amount / 2) * 10n ** BigInt(decimals0);
    const amount1 = BigInt(amount / 2) * 10n ** BigInt(decimals1);

    await coin0.connect(user).approve(context.curveLp, MaxUint256);
    await coin1.connect(user).approve(context.curveLp, MaxUint256);

    try {
        await lp.connect(user)["add_liquidity(uint256[],uint256)"]([amount0, amount1], 0n);
    } catch (err) {
        try {
            await lp.connect(user)["add_liquidity(uint256[2],uint256)"]([amount0, amount1], 0n);
        } catch (signatureError) {
            throw new Error(`Failed to add liquidity with both signatures: ${signatureError}`);
        }
    }

    return lp;
};

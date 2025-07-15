import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

type CurveLpKey = keyof typeof CURVE_CONTEXT;

export const depositCurveLP = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: bigint) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0 = await ethers.getContractAt("ERC20", coin0Address);
    const coin1 = await ethers.getContractAt("ERC20", coin1Address);

    const [decimals0, decimals1] = await Promise.all([coin0.decimals(), coin1.decimals()]);

    const scale0 = 10n ** BigInt(decimals0);
    const scale1 = 10n ** BigInt(decimals1);

    const totalScale = scale0 + scale1;
    const amount0 = (amount * scale0) / totalScale;
    const amount1 = amount - amount0;

    await coin0.connect(user).approve(lp.target, MaxUint256);
    await coin1.connect(user).approve(lp.target, MaxUint256);

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

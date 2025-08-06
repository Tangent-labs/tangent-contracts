import {ethers} from "hardhat";
import {MaxUint256, parseEther, parseUnits} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {safeApprove, transfer} from "./safeApprove";

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    CURVE LP 
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

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

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0 = await ethers.getContractAt("ERC20", coin0Address);
    const coin1 = await ethers.getContractAt("ERC20", coin1Address);

    const [decimals0, decimals1] = await Promise.all([coin0.decimals(), coin1.decimals()]);

    const amountDiv = (Number(amount) / 2).toString();

    const amount0 = parseUnits(amountDiv, decimals0);
    const amount1 = parseUnits(amountDiv, decimals1);

    await safeApprove(coin0, user, context.curveLp, MaxUint256);
    await safeApprove(coin1, user, context.curveLp, MaxUint256);

    try {
        await lp.connect(user)["add_liquidity(uint256[],uint256)"]([amount0, amount1], 0n);
    } catch (err) {
        console.warn("First add_liquidity signature failed, trying second...");
        try {
            await lp.connect(user)["add_liquidity(uint256[2],uint256)"]([amount0, amount1], 0n);
        } catch (signatureError) {
            throw new Error(`Failed to add liquidity with both signatures: ${signatureError}`);
        }
    }

    return lp;
};

export const withdrawCurveLP = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);

    try {
        await lp.connect(user)["remove_liquidity(uint256,uint256[])"](parseEther(amount.toString()), [0n, 0n]);
    } catch (err) {
        try {
            await lp.connect(user)["remove_liquidity(uint256,uint256[2],address)"](parseEther(amount.toString()), [0n, 0n], user);
        } catch (signatureError) {
            throw new Error(`Failed to remove liquidity with both signatures: ${signatureError}`);
        }
    }

    return lp;
};

export async function transferCurveLP(lpKey: CurveLpKey, from: HardhatEthersSigner, to: HardhatEthersSigner, amount: number) {
    const context = CURVE_CONTEXT[lpKey];
    await transfer(context.curveLp, from, to, amount);
}

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    CURVE GAUGE 
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
export const depositCurveGauge = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];

    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", context.curveGauge);

    const bal = await lp.balanceOf(user);
    const amBigInt = parseEther(amount.toString());

    if (bal >= amBigInt) {
        await lp.connect(user).approve(gauge, MaxUint256);
        await gauge.connect(user)["deposit(uint256)"](parseEther(amount.toString()));
    } else {
        throw Error(`Not enough ${lpKey} LP to Deposit in Curve Gauge`);
    }
};
export const withdrawCurveGauge = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];

    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", context.curveGauge);

    const bal = await gauge.balanceOf(user);
    const amBigInt = parseEther(amount.toString());

    if (bal >= amBigInt) {
        await gauge.connect(user)["withdraw(uint256)"](amBigInt);
    } else {
        throw Error("Not enough Curve Gauge token to withdraw from " + lpKey);
    }
};

export async function transferCurveGauge(lpKey: CurveLpKey, from: HardhatEthersSigner, to: HardhatEthersSigner, amount: number) {
    const context = CURVE_CONTEXT[lpKey];
    await transfer(context.curveGauge, from, to, amount);
}

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    CONVEX 
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

export const depositConvex = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];

    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const booster = await ethers.getContractAt("ICvxBooster", "0xF403C135812408BFbE8713b5A23a04b3D48AAE31");

    await lp.connect(user).approve(booster, MaxUint256);
    await booster.connect(user).deposit(context.convexPID, parseEther(amount.toString()), true);
};
export const withdrawConvex = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];
    const rewardsContract = await ethers.getContractAt("ICvxRewardToken", context.convexRewardToken);
    await rewardsContract.connect(user).withdrawAndUnwrap(parseEther(amount.toString()), true);
};

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    STAKE DAO  
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

export const depositStakeDao = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];
    const lp = await ethers.getContractAt("ICurveStableSwapNG", context.curveLp);
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", context.stakeDaoVault);
    await lp.connect(user).approve(stakeVault, MaxUint256);
    await stakeVault.connect(user).deposit(user, parseEther(amount.toString()), true);
};
export const withdrawStakeDao = async (lpKey: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[lpKey];
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", context.stakeDaoVault);
    await stakeVault.connect(user).withdraw(parseEther(amount.toString()));
};

export async function transferStakeDaoGauge(lpKey: CurveLpKey, from: HardhatEthersSigner, to: HardhatEthersSigner, amount: number) {
    const context = CURVE_CONTEXT[lpKey];
    await transfer(context.stakeDaoGauge, from, to, amount);
}

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    LLAMALEND  
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
export const depositLlamaLend = async (key: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[key];

    const vault = await ethers.getContractAt("ILlamaVault", context.curveLp);
    const tokenAddress = await vault.asset();
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress);

    await erc20.connect(user).approve(vault, MaxUint256);
    await vault.connect(user)["deposit(uint256)"](parseEther(amount.toString()));
};
export const withdrawLlamaLend = async (key: CurveLpKey, user: HardhatEthersSigner, amount: number) => {
    const context = CURVE_CONTEXT[key];
    const vault = await ethers.getContractAt("ILlamaVault", context.curveLp);
    await vault.connect(user)["withdraw(uint256)"](parseEther(amount.toString()));
};

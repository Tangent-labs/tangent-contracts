import {ethers} from "hardhat";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ICurveStableSwapNG} from "../../../../typechain-types/src/interfaces/externals/Curve/ICurveStableSwapNG";

// CURVE

export const depositOnCurveStableLp = async (address: string, amountToGive: number, firstTokenAmount: bigint, secondTokenAmount: bigint, user: HardhatEthersSigner) => {
    const lp = await ethers.getContractAt("ICurveStableSwapNG", address);

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0Contract = await ethers.getContractAt("ERC20", coin0Address);
    const coin1Contract = await ethers.getContractAt("ERC20", coin1Address);

    await giveTokensToAddresses([user], TOKENS_TO_GIVE(amountToGive));

    await coin0Contract.connect(user).approve(address, MaxUint256);
    await coin1Contract.connect(user).approve(address, MaxUint256);

    try {
        await lp.connect(user)["add_liquidity(uint256[],uint256)"]([firstTokenAmount, secondTokenAmount], 0n);
    } catch (err) {
        try {
            await lp.connect(user)["add_liquidity(uint256[2],uint256)"]([firstTokenAmount, secondTokenAmount], 0n);
        } catch (signatureError) {
            throw new Error(`Failed to add liquidity with both signatures: ${signatureError}`);
        }
    }

    return lp;
};

export const removeLiquidityOnCurveStableLp = async (address: string, amount: bigint, user: HardhatEthersSigner) => {
    const lp = await ethers.getContractAt("ICurveStableSwapNG", address);

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

export const depositOnCurveGauge = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, amount: bigint) => {
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", address);
    await lp.connect(user).approve(gauge, MaxUint256);
    gauge.connect(user)["deposit(uint256)"](amount);
};

export const withdrawOnCurveGauge = async (address: string, user: HardhatEthersSigner, amount: bigint) => {
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", address);
    gauge.connect(user)["withdraw(uint256)"](amount);
};

// STAKE

export const depositStakeDao = async (lp: ICurveStableSwapNG, address: string, user: HardhatEthersSigner, amount: bigint) => {
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", address);
    await lp.connect(user).approve(stakeVault, MaxUint256);
    await stakeVault.connect(user).deposit(user, amount, false);
};

export const withdrawStakeDao = async (address: string, user: HardhatEthersSigner, amount: bigint) => {
    const stakeVault = await ethers.getContractAt("IStakeDaoVault", address);
    await stakeVault.connect(user).withdraw(amount);
};

// CONVEX

export const depositConvex = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, pid: number, amount: bigint) => {
    const booster = await ethers.getContractAt("ICvxBooster", address);
    await lp.connect(user).approve(address, MaxUint256);
    await booster.connect(user).deposit(pid, amount, true);
};

//

export const withdrawConvex = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, amount: bigint) => {
    const rewardsContract = await ethers.getContractAt("ICvxRewardToken", address);
    await lp.connect(user).approve(address, MaxUint256);
    await rewardsContract.connect(user).withdrawAndUnwrap(amount, true);
};

// LLAMMALEND

export const depositLlamaLend = async (vaultAddress: string, tokenAddress: string, user: HardhatEthersSigner, tokenToGive: number, amountToDeposit: bigint) => {
    const vault = await ethers.getContractAt("ILlamaVault", vaultAddress);
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress);

    await giveTokensToAddresses([user], TOKENS_TO_GIVE(tokenToGive));

    await erc20.connect(user).approve(vault, MaxUint256);
    await vault.connect(user)["deposit(uint256)"](amountToDeposit);
};

export const withdrawLlamaLend = async (vaultAddress: string, user: HardhatEthersSigner, amountToWithdraw: bigint) => {
    const vault = await ethers.getContractAt("ILlamaVault", vaultAddress);

    await vault.connect(user)["withdraw(uint256)"](amountToWithdraw);
};

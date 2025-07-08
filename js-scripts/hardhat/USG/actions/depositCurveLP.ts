import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const depositCurveLP = async (address: string, firstTokenAmount: bigint, secondTokenAmount: bigint, user: HardhatEthersSigner) => {
    const lp = await ethers.getContractAt("ICurveStableSwapNG", address);

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0Contract = await ethers.getContractAt("ERC20", coin0Address);
    const coin1Contract = await ethers.getContractAt("ERC20", coin1Address);

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

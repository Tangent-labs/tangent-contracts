import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

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

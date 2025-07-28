import {ethers} from "hardhat";
import {AddressLike, MaxUint256, parseEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {IERC20Metadata} from "../../../../typechain-types";

export async function safeApprove(token: IERC20Metadata, user: HardhatEthersSigner, spender: string, amount: bigint) {
    const symbol = await token.symbol();

    try {
        const tx = await token.connect(user).approve(spender, MaxUint256);
        await tx.wait();
    } catch (err) {
        console.warn(`Standard approve failed for ${symbol}, trying raw tx...`);

        try {
            await user.sendTransaction({
                to: token.target,
                data: token.interface.encodeFunctionData("approve", [spender, 0]),
            });

            await user.sendTransaction({
                to: token.target,
                data: token.interface.encodeFunctionData("approve", [spender, MaxUint256]),
            });
            try {
                await token.connect(user).approve(spender, 0);
                await token.connect(user).approve(spender, MaxUint256);
            } catch (rawErr) {
                throw new Error(`Fallback raw approve failed for ${symbol}: ${rawErr}`);
            }
        } catch (rawErr) {
            throw new Error(`Fallback raw approve failed for ${symbol}: ${rawErr}`);
        }
    }
}

export async function transfer(erc20: AddressLike, from: HardhatEthersSigner, to: HardhatEthersSigner, amount: number) {
    try {
        const tokenContract = await ethers.getContractAt("ERC20", erc20.toString());
        const tx = await tokenContract.connect(from).transfer(to, parseEther(amount.toString()));
        await tx.wait();
    } catch (error) {
        console.error("Error in transferStakeDaoGauge:", error);
        throw error;
    }
}

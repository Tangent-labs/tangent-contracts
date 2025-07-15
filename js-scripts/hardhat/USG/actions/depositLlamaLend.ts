import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";

type LlamaKey = keyof typeof CURVE_CONTEXT;

export const depositLlamaLend = async (key: LlamaKey, user: HardhatEthersSigner, tokenToGive: number, amountToDeposit: bigint) => {
    const context = CURVE_CONTEXT[key];

    const vault = await ethers.getContractAt("ILlamaVault", context.curveLp);
    const tokenAddress = await vault.asset();
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress);

    await giveTokensToAddresses([user], TOKENS_TO_GIVE(tokenToGive));

    await erc20.connect(user).approve(vault, MaxUint256);
    await vault.connect(user)["deposit(uint256)"](amountToDeposit);
};

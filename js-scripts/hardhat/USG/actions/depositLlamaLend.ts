import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {CurveLpKey} from "./depositCurveLP";

export const depositLlamaLend = async (key: CurveLpKey, user: HardhatEthersSigner, amountToDeposit: bigint) => {
    const context = CURVE_CONTEXT[key];

    const vault = await ethers.getContractAt("ILlamaVault", context.curveLp);
    const tokenAddress = await vault.asset();
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress);

    await erc20.connect(user).approve(vault, MaxUint256);
    await vault.connect(user)["deposit(uint256)"](amountToDeposit);
};

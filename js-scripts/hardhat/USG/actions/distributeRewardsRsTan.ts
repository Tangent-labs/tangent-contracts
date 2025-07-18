import {MaxUint256, parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";

export async function distributeRewardsVsTan() {
    const USG = await ethers.getContractAt("USG", contractAddresses.tokens.USG);

    const vsTan = await ethers.getContractAt("VsTan", contractAddresses.tokens.vsTan);

    await USG.approve(vsTan, MaxUint256);

    await vsTan.processRewards([{token: contractAddresses.tokens.USG, amount: parseEther("1000")}]);

    console.info("\x1b[32m%s\x1b[0m", "Rewards distributed to VsTan with success !");
}

distributeRewardsVsTan();

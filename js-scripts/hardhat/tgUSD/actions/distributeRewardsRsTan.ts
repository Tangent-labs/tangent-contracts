import {MaxUint256, parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";

export async function distributeRewardsRsTan() {
    const tgUSD = await ethers.getContractAt("TgUSD", contractAddresses.tokens.tgUSD);

    const rsTan = await ethers.getContractAt("RsTan", contractAddresses.tokens.rsTan);

    await tgUSD.approve(rsTan, MaxUint256);

    await rsTan.processRewards([{token: contractAddresses.tokens.tgUSD, amount: parseEther("1000")}]);

    console.info("\x1b[32m%s\x1b[0m", "Rewards distributed to RsTan with success !");
}

distributeRewardsRsTan();

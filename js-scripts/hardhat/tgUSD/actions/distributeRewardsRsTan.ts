import {MaxUint256, parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";

export async function distributeRewardsRsTan() {
    const tgUSD = await ethers.getContractAt("TgUSD", contractAddresses.tokens.tgUSD);

    const rsTanService = await ethers.getContractAt("RsTanService", contractAddresses.lock.rsTanService);

    await tgUSD.approve(rsTanService, MaxUint256);

    await rsTanService.processRewards([{token: contractAddresses.tokens.tgUSD, amount: parseEther("1000")}]);

    console.info("\x1b[32m%s\x1b[0m", "Rewards distributed to RsTanService with success !");
}

distributeRewardsRsTan();

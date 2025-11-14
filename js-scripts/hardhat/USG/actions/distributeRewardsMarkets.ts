import { parseEther } from "ethers";
import { ethers } from "hardhat";
import * as contractAddresses from "../../../../addresses.json";

export async function distributeRewardsMarkets() {
    const allMarkets = contractAddresses.markets;
    for (let i = 0; i < allMarkets.length; i++) {
        const rewardAccumulator = await ethers.getContractAt("RewardAccumulator", contractAddresses.utilities.rewardAccumulator);
        const rewardTokens = await rewardAccumulator.getRewardTokens(allMarkets[i].marketAddress);

        for (let j = 0; j < rewardTokens.length; j++) {
            const erc20 = await ethers.getContractAt("ERC20", rewardTokens[j]);
            await erc20.transfer(allMarkets[i].marketAddress, parseEther("1000"));
        }
    }
    console.info("\x1b[32m%s\x1b[0m", "Rewards distributed to all markets with success !");
}

distributeRewardsMarkets();

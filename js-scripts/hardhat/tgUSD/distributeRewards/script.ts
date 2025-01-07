import {parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";

export function getAllMarkets() {
    const marketsConvexCrv = Object.values(contractAddresses.markets.convexCrvMarkets).map((market) => market);
    const marketsConvexFxn = Object.values(contractAddresses.markets.convexFxnMarkets).map((market) => market);

    return [...marketsConvexCrv, ...marketsConvexFxn];
}

export async function distributeRewards() {
    const allMarkets = getAllMarkets();
    for (let i = 0; i < allMarkets.length; i++) {
        const market = await ethers.getContractAt("IRewards", allMarkets[i]);
        const rewardTokens = await market.getRewardTokens();

        for (let j = 0; j < rewardTokens.length; j++) {
            const erc20 = await ethers.getContractAt("ERC20", rewardTokens[j]);
            await erc20.transfer(market, parseEther("1000"));
        }
    }
}

distributeRewards();

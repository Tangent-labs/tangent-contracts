import { ethers } from "hardhat";
import { filterAndGetTokenHoldersAmount } from "../erc20Strat/erc20BalanceSnapshot";

export async function getLpDetails(lpAddress: string, lpName: string, lpCreationBlock: number, excludedAddresses: string[], minValue: number) {
    await filterAndGetTokenHoldersAmount(lpAddress, lpName, lpCreationBlock, excludedAddresses, minValue)
}

export async function findConvexId(lpAddress: string) {
    const convexBooster = await ethers.getContractAt("ICvxBooster", "0xF403C135812408BFbE8713b5A23a04b3D48AAE31")
    for (let pid = 300; pid < 500; pid++) {
        const poolInfo = await convexBooster.poolInfo(pid)
        if (poolInfo.lptoken.toLowerCase() === lpAddress.toLowerCase()) {
            console.log(`PID of LP is ${pid.toString()} and CvxRewardToken ${poolInfo.crvRewards}`)
            return pid
        }
    }
}
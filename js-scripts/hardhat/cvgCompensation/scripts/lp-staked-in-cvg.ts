import { formatEther } from "ethers";
import fs from 'fs/promises';
import { ethers } from "hardhat";


export async function recomputeLockers() {
    const positionManager = await ethers.getContractAt("ISdtStakingManager", "0x7319662aD7D7ce2d1595073EA042B723F6d0dc48")
    const stakingService = await ethers.getContractAt("ISdtStaking", "0x42ac76385DE5Eae2FCd5a04601Aea8472E453882")

    const nftSupply = await positionManager.totalSupply();
    const amountStaked: { [account: string]: bigint } = {};

    const cycleId = await stakingService.stakingCycle() - 1n

    console.log(cycleId, await stakingService.cycleInfo(cycleId))


    for (let tokenId = 1; tokenId <= nftSupply; tokenId++) {


        try {
            const tokenOwner = await positionManager.ownerOf(tokenId)


            const staking = await positionManager.stakingPerTokenId(tokenId)
            // console.log(tokenOwner, staking)

            // Count in the 
            if (staking.toLowerCase() === (await stakingService.getAddress()).toLowerCase()) {

                const lpStaked = await stakingService.tokenTotalStaked(tokenId)
                // console.log(tokenId, lpStaked)

                if (!amountStaked[tokenOwner]) {
                    amountStaked[tokenOwner] = lpStaked
                } else {
                    amountStaked[tokenOwner] += lpStaked
                }
            }


        }
        catch (e) {
            console.error(tokenId, "not doesn't exist")
        }
    }

    Object.entries(amountStaked).forEach(([addr, bal]) => {
        if (BigInt(bal) === 0n) {
            delete amountStaked[addr];
        }
    });

    const finalResults = Object.entries(amountStaked)
        .map(([k, v]) => {
            return { address: k, value: v.toString() };
        })
        .sort((a, b) => Number(formatEther(b.value)) - Number(formatEther(a.value)))


    await fs.writeFile(`./js-scripts/hardhat/cvgCompensation/snapshotitos/lp-staked-in-cvg.json`, JSON.stringify(finalResults, null, 2));
}

recomputeLockers()
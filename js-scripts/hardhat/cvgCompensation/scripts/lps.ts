import { expect } from "chai";
import { ethers } from "hardhat";


export async function getLpRecomputed(allVoters: string[]) {
    const cvgETHLP = "0x004c167d27ada24305b76d80762997fa6eb8d9b2"
    const cvgETHCurveGauge = "0x16a3a047fc1d388d5846a73acdb475b11228c299"
    const cvgETHSdtGauge = "0xd79d3329560489835265D4d100583f21AC9C4A3e"
    const cvgETHConvexCurve = ""

    const cvgFraxBpLP = "0xa7b0e924c2dbb9b4f576cce96ac80657e42c3e42"
    const cvgFraxBpCurveGauge = "0x8a111b47b31bba40c2f0d2f9a8cf6b6c4b50114e"
    const cvgFraxBpSdtGauge = ""
    const cvgFraxBpConvexCurve = ""
    const cvgFraxBpConvexCurve = ""



    const sdtStakingManager = await ethers.getContractAt("ISdtStakingManager", "0x7319662aD7D7ce2d1595073EA042B723F6d0dc48")
    const cvgETHStakingService = await ethers.getContractAt("ISdtStaking", "0x42ac76385DE5Eae2FCd5a04601Aea8472E453882")


    const stakingPositionAmount = await sdtStakingManager.nextId();

    const totalLpCvgEthStaked: bigint = (await cvgETHStakingService.cycleInfo(26)).totalStaked;
    let recomposedLp = 0n;

    const votingLpRecomputed: { [account: string]: bigint | number | string } = {};
    const cvgEthPositionPerUser: { [account: string]: number[] } = {};

    for (let tokenId = 1; tokenId <= stakingPositionAmount; tokenId++) {
        try {
            const tokenOwner = await sdtStakingManager.ownerOf(tokenId);
            const service = await sdtStakingManager.stakingPerTokenId(tokenId);
            if (service === (await cvgETHStakingService.getAddress())) {
                if (!allVoters.includes(tokenOwner)) {
                    allVoters.push(tokenOwner);
                }
                const stakedAmount = await cvgETHStakingService.stakedAmountEligibleAtCycle(26, tokenId, 27);

                recomposedLp += stakedAmount;

                const votingValue = (BigInt(stakedAmount) * 10n ** 24n) / totalLpCvgEthStaked / 4n;

                votingLpRecomputed[tokenOwner] = votingValue;

                if (!cvgEthPositionPerUser[tokenOwner]) {
                    cvgEthPositionPerUser[tokenOwner] = [tokenId];
                } else {
                    cvgEthPositionPerUser[tokenOwner].push(tokenId);
                }
            }
        } catch (e) {
            console.error(tokenId + " is burnt");
        }
    }

    expect(recomposedLp).to.be.eq(totalLpCvgEthStaked);
    console.log("totalLp", ethers.formatEther(totalLpCvgEthStaked));

    return votingLpRecomputed;
}

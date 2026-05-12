import { formatEther } from "ethers";
import fs from 'fs/promises';
import { ethers } from "hardhat";


export async function recomputeVesting() {
    await _generateExtractForVestingType(0, "seed", "0x06FEB7a047e540B8d92620a2c13Ec96e1FF5E19b")
    await _generateExtractForVestingType(1, "wl", "0xc9740aa94A8A02a3373f5F1b493D7e10d99AE811")
    await _generateExtractForVestingType(2, "ibo", "0x5F02134C35449D9b6505723A56b02581356320fB")

}


async function _generateExtractForVestingType(vestingType: number, fileName: string, nftAddress: string) {
    const vestingCVG = await ethers.getContractAt("IVestingCvg", "0xC929bA60ef82fE55De3bC848dd9453B3b12a0c30")
    const nftContract = await ethers.getContractAt("ERC721Enumerable", nftAddress)


    const seedPositionAmount = await nftContract.totalSupply();
    const amountInvestsRecomputed: { [account: string]: { bought: bigint | number | string; claimed: bigint | number | string } } = {};
    for (let tokenId = 1; tokenId <= seedPositionAmount; tokenId++) {
        const tokenOwner = await nftContract.ownerOf(tokenId)
        const vestingData = await vestingCVG.getInfoVestingTokenId(tokenId, vestingType);
        const cvgBought = vestingData.totalCvg;
        const claimedCvg = vestingData.amountRedeemed;

        if (!amountInvestsRecomputed[tokenOwner]) {
            amountInvestsRecomputed[tokenOwner] = { bought: cvgBought, claimed: claimedCvg }
        } else {
            (amountInvestsRecomputed[tokenOwner].bought as bigint) += cvgBought;
            (amountInvestsRecomputed[tokenOwner].claimed as bigint) += claimedCvg;
        }
    }

    Object.entries(amountInvestsRecomputed).forEach(([addr, bal]) => {
        if (BigInt(bal.bought) === 0n) {
            delete amountInvestsRecomputed[addr];
        }
    });

    const finalResults = Object.entries(amountInvestsRecomputed)
        .map(([k, v]) => {
            return { address: k, values: { bought: v.bought.toString(), claimed: v.claimed.toString() } };
        })
        .sort((a, b) => Number(formatEther(b.values.bought)) - Number(formatEther(a.values.bought)))


    await fs.writeFile(`./js-scripts/hardhat/cvgCompensation/snapshotitos/${fileName}.json`, JSON.stringify(finalResults, null, 2));
}
recomputeVesting()
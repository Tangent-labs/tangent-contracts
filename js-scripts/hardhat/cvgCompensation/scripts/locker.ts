import { formatEther } from "ethers";
import fs from 'fs/promises';
import { ethers } from "hardhat";


export async function recomputeLockers() {
    const nft = await ethers.getContractAt("ERC721Enumerable", "0x0EDB88Aa3aa665782121fA2509b382f414A0C0cE")
    const lockingPositionService = await ethers.getContractAt("ILockingPositionService", "0xc8a6480ed7C7B1C401061f8d96bE7De6f94D3E60")

    const lockingPositionAmount = await nft.totalSupply();
    const amountLocked: { [account: string]: bigint } = {};

    for (let tokenId = 1; tokenId <= lockingPositionAmount; tokenId++) {


        try {
            const tokenOwner = await nft.ownerOf(tokenId)
            const cvgLocked = (await lockingPositionService.lockingPositions(tokenId)).totalCvgLocked;

            if (!amountLocked[tokenOwner]) {
                amountLocked[tokenOwner] = cvgLocked
            } else {
                amountLocked[tokenOwner] += cvgLocked
            }
        }
        catch (e) {
            console.error(tokenId, "not doesn't exist")
        }
    }

    Object.entries(amountLocked).forEach(([addr, bal]) => {
        if (BigInt(bal) === 0n) {
            delete amountLocked[addr];
        }
    });

    const finalResults = Object.entries(amountLocked)
        .map(([k, v]) => {
            return { address: k, value: v.toString() };
        })
        .sort((a, b) => Number(formatEther(b.value)) - Number(formatEther(a.value)))


    await fs.writeFile(`./js-scripts/hardhat/cvgCompensation/snapshotitos/lockers.json`, JSON.stringify(finalResults, null, 2));
}

recomputeLockers()
import { formatEther } from "ethers";
import fs from 'fs/promises';
import { ethers } from "hardhat";


export async function computeBonds() {
    const nft = await ethers.getContractAt("ERC721Enumerable", "0x59e8fBceAC829B7da182D8F749BA4a038C6272Ea")
    const bondDepository = await ethers.getContractAt("IBondDepository", "0xEa3C304fAb04AA459a5E4712e06Eb22Ef3624420")

    const lockingPositionAmount = await nft.totalSupply();
    const amountLocked: { [account: string]: bigint } = {};

    // iterate by index: burned NFTs make max tokenId > totalSupply
    for (let i = 0; i < lockingPositionAmount; i++) {
        const tokenId = await nft.tokenByIndex(i)


        try {
            const tokenOwner = await nft.ownerOf(tokenId)
            const vesting = await bondDepository.getTokenVestingInfo(tokenId);
            const cvgClaimable = vesting.claimable + vesting.pending; // unclaimed = vested + still vesting

            if (!amountLocked[tokenOwner]) {
                amountLocked[tokenOwner] = cvgClaimable
            } else {
                amountLocked[tokenOwner] += cvgClaimable
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


    await fs.writeFile(`./js-scripts/hardhat/cvgCompensation/snapshotitos/bonds.json`, JSON.stringify(finalResults, null, 2));
}

computeBonds()
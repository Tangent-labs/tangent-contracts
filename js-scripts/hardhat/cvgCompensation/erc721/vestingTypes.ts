import { Contract, formatEther } from "ethers";
import { ethers } from "hardhat";
import fs from "fs/promises";
import path from "path"

import * as VestingCvgAbi from "./abis/VestingCvg.json"

export async function vestingSnapshot(vestingName: string, vestingId: number, contractAddress: string) {
    const nft = await ethers.getContractAt("ERC721Enumerable", contractAddress)
    const vesting = new Contract("0xC929bA60ef82fE55De3bC848dd9453B3b12a0c30", VestingCvgAbi.abi, ethers.provider)

    const snapshotBigInt: { [address: string]: { totalBought: bigint, releasable: bigint, redeemed: bigint, accountedBalance: bigint, positionAmount: number } } = {}
    const totalSupply = await nft.totalSupply()
    let totalUnclaimed = 0n
    let totalBought = 0n
    for (let tokenId = 1; tokenId <= totalSupply; tokenId++) {
        const owner = (await nft.ownerOf(tokenId)).toLowerCase()
        if (!snapshotBigInt[owner]) {
            snapshotBigInt[owner] = { redeemed: 0n, releasable: 0n, totalBought: 0n, accountedBalance: 0n, positionAmount: 0 }
        }

        const { amountReleasable, totalCvg, amountRedeemed } = await vesting.getInfoVestingTokenId(tokenId, vestingId) as { amountReleasable: bigint, totalCvg: bigint, amountRedeemed: bigint }
        const accounted = totalCvg - amountRedeemed
        totalUnclaimed += accounted
        totalBought += totalCvg
        snapshotBigInt[owner] = {
            accountedBalance: snapshotBigInt[owner].accountedBalance + accounted,
            releasable: snapshotBigInt[owner].releasable + amountReleasable,
            totalBought: snapshotBigInt[owner].totalBought + totalCvg,
            redeemed: snapshotBigInt[owner].redeemed + amountRedeemed,
            positionAmount: snapshotBigInt[owner].positionAmount + 1,

        }
        snapshotBigInt[owner].positionAmount += 1
    }
    const snapshot: { [address: string]: { totalBought: string, releasable: string, redeemed: string, accountedBalance: string, positionAmount: number } } = {}
    let snapshotSorted: {
        totalUnclaimed: number,
        totalBought: number,
        balances: { address: string, totalBought: number, releasable: number, redeemed: number, accountedBalance: number, positionAmount: number }[]
    } = { totalBought: Number(formatEther(totalBought)), totalUnclaimed: Number(formatEther(totalUnclaimed)), balances: [] }


    Object.entries(snapshotBigInt).forEach(([address, data]) => {
        snapshot[address] = {
            accountedBalance: data.accountedBalance.toString(),
            positionAmount: data.positionAmount,
            redeemed: data.redeemed.toString(),
            releasable: data.releasable.toString(),
            totalBought: data.totalBought.toString()
        }
        snapshotSorted.balances.push({
            address: address,
            accountedBalance: Number(formatEther(data.accountedBalance)),
            positionAmount: data.positionAmount,
            redeemed: Number(formatEther(data.redeemed)),
            releasable: Number(formatEther(data.releasable)),
            totalBought: Number(formatEther(data.totalBought)),
        })
    })

    snapshotSorted.balances = snapshotSorted.balances.sort((a, b) => b.accountedBalance - a.accountedBalance)

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${vestingName}.json`),
        JSON.stringify(snapshot, null, 2),
        "utf8"
    );

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${vestingName}_sorted.json`),
        JSON.stringify(snapshotSorted, null, 2),
        "utf8"
    );
}


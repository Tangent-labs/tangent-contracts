import { Contract, formatEther } from "ethers";
import { ethers } from "hardhat";
import fs from "fs/promises";
import path from "path"

import * as LockingPositionServiceAbi from "./abis/LockingPositionServiceV3.json"
import * as LockingPositionManagerAbi from "./abis/LockingPositionManager.json"

export async function lockSnapshot() {
    const lockingPositionService = new Contract("0xc8a6480ed7C7B1C401061f8d96bE7De6f94D3E60", LockingPositionServiceAbi.abi, ethers.provider)
    const lockingPositionManager = new Contract("0x0EDB88Aa3aa665782121fA2509b382f414A0C0cE", LockingPositionManagerAbi.abi, ethers.provider)

    const snapshotBigInt: { [address: string]: { totalLock: bigint, positionAmount: number } } = {}
    const totalSupply = await lockingPositionManager.totalSupply()
    let totalLock = 0n
    for (let tokenId = 1; tokenId <= totalSupply; tokenId++) {
        try {
            const owner = (await lockingPositionManager.ownerOf(tokenId)).toLowerCase()
            if (!snapshotBigInt[owner]) {
                snapshotBigInt[owner] = { totalLock: 0n, positionAmount: 0 }
            }
            const { startCycle, endCycle, ysPercentage, totalCvgLocked, mgCvgAmount } = await lockingPositionService.lockingPositions(tokenId) as { startCycle: bigint, endCycle: bigint, ysPercentage: bigint, totalCvgLocked: bigint, mgCvgAmount: bigint }
            totalLock += totalCvgLocked
            snapshotBigInt[owner].totalLock += totalCvgLocked
            snapshotBigInt[owner].positionAmount += 1
        }
        catch (e: any) {
            if ((e.toString() as string).includes("ERC721: invalid token ID")) {
                console.error(`TokenId ${tokenId} doesn't exist`)
            }
            else {
                console.error(e)
            }
        }

    }
    const snapshot: { [address: string]: { totalLock: string, positionAmount: number } } = {}
    let snapshotSorted: {
        totalLock: number,
        balances: { address: string, totalLock: number, positionAmount: number }[]
    } = { totalLock: Number(formatEther(totalLock)), balances: [] }


    Object.entries(snapshotBigInt).forEach(([address, data]) => {
        snapshot[address] = {
            positionAmount: data.positionAmount,
            totalLock: data.totalLock.toString()
        }
        snapshotSorted.balances.push({
            address: address,
            totalLock: Number(formatEther(data.totalLock)),
            positionAmount: data.positionAmount,
        })
    })

    snapshotSorted.balances = snapshotSorted.balances.sort((a, b) => b.totalLock - a.totalLock)

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${"locking"}.json`),
        JSON.stringify(snapshot, null, 2),
        "utf8"
    );

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${"locking"}_sorted.json`),
        JSON.stringify(snapshotSorted, null, 2),
        "utf8"
    );
}


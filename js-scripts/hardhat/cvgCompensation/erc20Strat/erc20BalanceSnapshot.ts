import { ethers } from "hardhat";
import { EXPLOIT_BLOCK } from "../config";
import { formatEther, Log, ZeroAddress } from "ethers";
import fs from "fs/promises";
import path from "path"

export async function filterAndGetTokenHoldersAmount(tokenAddress: string, tokenName: string, tokenCreationBlock: number, rangeBlock: number, excludedAddresses: string[]) {
    const final: { [address: string]: string } = {}
    const ranks: { total: number, balances: { address: string, value: number }[] } = { total: 0, balances: [] }

    try {
        const data = await fs.readFile(
            path.join(__dirname, `/snapshot_${tokenName}_holders_unfiltered.json`),
            "utf8"
        );

        const snapshot = JSON.parse(data) as { [address: string]: string };



        let total = 0n
        Object.entries(snapshot).forEach(([k, v]) => {
            const value = Number(formatEther(v))
            if (!excludedAddresses.includes(k) && value >= 1) {
                ranks.balances.push({ address: k, value })
                final[k] = v
                total += BigInt(v)
            }
        })
        ranks.balances = ranks.balances.sort((a, b) => b.value - a.value)
        ranks.total = Number(formatEther(total))

    }
    catch (e) {
        await getAllCvgHolders(tokenAddress, tokenName, tokenCreationBlock, rangeBlock)
        await filterAndGetTokenHoldersAmount(tokenAddress, tokenName, tokenCreationBlock, rangeBlock, excludedAddresses)
        return
    }

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${tokenName}_holders_filtered.json`),
        JSON.stringify(final, null, 2),
        "utf8"
    );

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${tokenName}_sorted.json`),
        JSON.stringify(ranks, null, 2),
        "utf8"
    );
}

export async function getAllCvgHolders(tokenAddress: string, tokenName: string, tokenCreationBlock: number, range: number) {
    const erc20 = await ethers.getContractAt("ERC20", tokenAddress)

    // Topic Transfer ERC20 (compatible ethers v5 et v6)
    const transferTopic = ethers.keccak256(
        ethers.toUtf8Bytes("Transfer(address,address,uint256)")
    );

    // Interface pour décoder les logs
    const iface = new ethers.Interface([
        "event Transfer(address indexed from, address indexed to, uint256 value)"
    ]);

    let logs: Log[] = []
    // Get all transfers of CVG through event
    for (let block = tokenCreationBlock; block < EXPLOIT_BLOCK;) {
        const fromBlock = block
        let toBlock = fromBlock + range
        toBlock = toBlock > EXPLOIT_BLOCK ? EXPLOIT_BLOCK : toBlock

        logs = logs.concat(await ethers.provider.getLogs({
            address: await erc20.getAddress(),
            fromBlock,
            toBlock,
            topics: [transferTopic]
        }));

        block = toBlock + 1
    }

    console.log(`Trouvé ${logs.length} événements Transfer ERC20 (tous tokens)`);


    // Recompose balance per user 

    const sumup: { [address: string]: bigint } = {}
    let total = 0n
    logs.forEach(log => {

        const params = iface.parseLog(log)?.args!;
        const from = params.from.toLowerCase()
        const to = params.to.toLowerCase()
        const amount = params.value
        // Mint
        if (params.from === ZeroAddress) {
            sumup[to] = (sumup[to] || 0n) + amount
            total += amount
        }
        // Burn
        else if (params.to === ZeroAddress) {
            sumup[from] = (sumup[from] || 0n) - amount
            total -= amount

        }
        // transfer between addres
        else {
            sumup[from] = (sumup[from] || 0n) - amount
            sumup[to] = (sumup[to] || 0n) + amount
        }
    })

    const sumupString: { [address: string]: string } = {}

    Object.entries(sumup).forEach(([k, v]) => {
        if (v !== 0n) {
            sumupString[k] = v.toString()
        }
    })

    await fs.writeFile(
        path.join(__dirname, `/snapshot_${tokenName}_holders_unfiltered.json`),
        JSON.stringify(sumupString, null, 2),
        "utf8"
    );

}
import { ethers } from "hardhat";
import { EXPLOIT_BLOCK, START_BLOCK } from "../config";
import { formatEther, Log, ZeroAddress } from "ethers";
import * as fs from "fs";
import * as path from "path";
import { stakedTopic, withdrawnTopic } from "..";

export type KeyMapString = { [address: string]: { balBigInt: string, balNumber: number } }
export type KeyMapBigInt = { [address: string]: bigint }

export type FileExportedNumber = { total: number, balances: { address: string, value: number }[] }
export type FileExportedBigInt = { totalBigInt: string, totalNumber: number, balances: KeyMapString }


export type RecomposeFunction = (logs: Log[]) => { total: bigint, balances: KeyMapBigInt };


const blockRange = 50_000

const transferTopic = ethers.keccak256(ethers.toUtf8Bytes("Transfer(address,address,uint256)"))


export async function recomposeBalancesForERC20WithLogs(tokenAddress: string, tokenName: string, excludedAddresses: string[], minValue: number) {
    await recomposeBalancesWithLogs(tokenAddress, tokenName, excludedAddresses, minValue, [transferTopic], recomposeERC20Holders)
}

export async function recomposeBalancesForConvexWithLogs(tokenAddress: string, tokenName: string, excludedAddresses: string[], minValue: number) {
    await recomposeBalancesWithLogs(tokenAddress, tokenName, excludedAddresses, minValue, [stakedTopic, withdrawnTopic], recomposeConvexHolders)
}

export async function recomposeBalancesWithLogs(tokenAddress: string, tokenName: string, excludedAddresses: string[], minValue: number, topics: string[], recomposeFunction: RecomposeFunction) {
    const final: FileExportedBigInt = { balances: {}, totalBigInt: "0", totalNumber: 0 }
    const ranks: FileExportedNumber = { total: 0, balances: [] }

    const folderPath = path.join(__dirname, tokenName);
    try {

        const filePath = path.join(folderPath, "raw.json");


        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }
        const data = fs.readFileSync(
            filePath,
            "utf8"
        );
        const snapshot = JSON.parse(data) as FileExportedBigInt;

        let total = 0n
        Object.entries(snapshot.balances).forEach(([k, v]) => {

            if (!excludedAddresses.includes(k) && v.balNumber >= minValue) {
                ranks.balances.push({ address: k, value: v.balNumber })
                final.balances[k] = v
                total += BigInt(v.balBigInt)
            }
        })
        const totalNumber = Number(formatEther(total))
        final.totalBigInt = total.toString()
        final.totalNumber = totalNumber
        ranks.balances = ranks.balances.sort((a, b) => b.value - a.value)
        ranks.total = totalNumber

    }
    catch (e) {
        await getLogsAndRecomposeHolders(
            tokenAddress,
            tokenName,
            topics,
            recomposeFunction
        )
        await recomposeBalancesWithLogs(tokenAddress, tokenName, excludedAddresses, minValue, topics, recomposeFunction)
        return
    }

    fs.writeFileSync(
        path.join(folderPath, `filtered.json`),
        JSON.stringify(final, null, 2),
        "utf8"
    );

    fs.writeFileSync(
        path.join(folderPath, `sorted.json`),
        JSON.stringify(ranks, null, 2),
        "utf8"
    );
}


export async function getLogsAndRecomposeHolders(tokenAddress: string, tokenName: string, topics: string[], recomposeHolders: RecomposeFunction) {
    const logs = await getLogs(tokenAddress, topics, START_BLOCK)
    const { total, balances } = recomposeHolders(logs)
    await convertDumpToStringAndSaveUnfiltered(tokenName, total, balances)
}

export async function getLogs(tokenAddress: string, topics: string[], tokenCreationBlock: number) {
    let logs: Log[] = []
    // Get all transfers of CVG through event
    for (let block = tokenCreationBlock; block <= EXPLOIT_BLOCK;) {
        const fromBlock = block
        let toBlock = fromBlock + blockRange
        toBlock = toBlock > EXPLOIT_BLOCK ? EXPLOIT_BLOCK : toBlock
        // console.log(fromBlock, toBlock)

        logs = logs.concat(await ethers.provider.getLogs({
            address: tokenAddress,
            fromBlock,
            toBlock,
            topics: [topics]
        }));

        block = toBlock + 1
    }
    return logs
}

export function recomposeERC20Holders(logs: Log[]) {
    const iFace = new ethers.Interface(["event Transfer(address indexed from, address indexed to, uint256 value)"])
    // Recompose balance per user 
    const balances: KeyMapBigInt = {}
    let total = 0n
    logs.forEach(log => {
        const params = iFace.parseLog(log)?.args!;
        const from = params.from.toLowerCase()
        const to = params.to.toLowerCase()
        const amount = params.value
        // Mint
        if (from === ZeroAddress.toLowerCase()) {
            balances[to] = (balances[to] || 0n) + amount
            total += amount
        }
        // Burn
        else if (to === ZeroAddress.toLowerCase()) {
            balances[from] = (balances[from] || 0n) - amount
            total -= amount

        }
        // transfer between addres
        else {
            balances[from] = (balances[from] || 0n) - amount
            balances[to] = (balances[to] || 0n) + amount
        }
    })
    return { total, balances }
}

export function recomposeConvexHolders(logs: Log[]) {
    const iface = new ethers.Interface(["event Staked(address indexed from, uint256 amount)", "event Withdrawn(address indexed from, uint256 amount)"]);
    // Recompose balance per user 
    const balances: KeyMapBigInt = {}
    let total = 0n
    logs.forEach(log => {
        const params = iface.parseLog(log)?.args!;
        const from = params.from.toLowerCase()
        const amount = params.amount
        // Staked
        if (log.topics[0] === stakedTopic) {
            balances[from] = (balances[from] || 0n) + amount
            total += amount
        }
        // Withdrawn
        else {
            balances[from] = (balances[from] || 0n) - amount
            total -= amount
        }
    })
    return { total, balances }
}





export async function convertDumpToStringAndSaveUnfiltered(tokenName: string, total: bigint, balances: KeyMapBigInt) {
    const finalString: FileExportedBigInt = { balances: {}, totalBigInt: total.toString(), totalNumber: Number(formatEther(total)) }
    const folderPath = path.join(__dirname, tokenName);

    Object.entries(balances).forEach(([k, v]) => {
        if (v !== 0n) {
            finalString.balances[k] = { balBigInt: v.toString(), balNumber: Number(formatEther(v)) }
        }
    })

    fs.writeFileSync(
        path.join(folderPath, `raw.json`),
        JSON.stringify(finalString, null, 2),
        "utf8"
    );
}


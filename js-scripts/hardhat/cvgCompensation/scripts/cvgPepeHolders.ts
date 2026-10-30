import fs from 'fs/promises';
import { ZeroAddress } from "ethers";

// Usage: ETHERSCAN_API_KEY=... npx hardhat run js-scripts/hardhat/cvgCompensation/scripts/cvgPepeHolders.ts
const CONTRACT_ADDRESS = "0x822ee3715e2c15372e45a4a62376bf786ff45511";
const TOPIC0_TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";
const SLEEP_MS = 400;

interface EtherscanLog {
    blockNumber: string;
    transactionHash: string;
    logIndex: string;
    topics: string[];
}

async function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchLogs(fromBlock: number): Promise<EtherscanLog[]> {
    const url = `https://api.etherscan.io/v2/api` +
        `?module=logs` +
        `&action=getLogs` +
        `&chainid=1` +
        `&address=${CONTRACT_ADDRESS}` +
        `&topic0=${TOPIC0_TRANSFER}` +
        `&fromBlock=${fromBlock}` +
        `&toBlock=latest` +
        `&page=1&offset=1000` +
        `&apikey=${process.env.ETHERSCAN_API_KEY}`;

    const data = await (await fetch(url)).json();
    if (data.status === '0' && data.message === 'No records found') return [];
    if (data.status !== '1') throw new Error(`API Error: ${data.message}`);
    return data.result;
}

async function main() {
    // tokenId => current owner, replayed from every Transfer in order
    const owners: { [tokenId: string]: string } = {};
    const seen = new Set<string>();
    let fromBlock = 0;

    while (true) {
        console.log(`Fetching from block ${fromBlock}`);
        const logs = await fetchLogs(fromBlock);

        for (const log of logs) {
            // Batches overlap on their boundary block
            const id = `${log.transactionHash}-${log.logIndex}`;
            if (seen.has(id)) continue;
            seen.add(id);

            const to = `0x${log.topics[2].slice(26)}`;
            const tokenId = BigInt(log.topics[3]).toString();
            if (to === ZeroAddress) delete owners[tokenId];
            else owners[tokenId] = to;
        }

        // Etherscan caps at 1000 logs per call: restart from the last block reached
        if (logs.length < 1000) break;
        fromBlock = parseInt(logs[logs.length - 1].blockNumber);
        await sleep(SLEEP_MS);
    }

    const holders: { [address: string]: number } = {};
    for (const owner of Object.values(owners)) holders[owner] = (holders[owner] ?? 0) + 1;

    const sortedHolders = Object.fromEntries(Object.entries(holders).sort((a, b) => b[1] - a[1]));
    const output = { contract: CONTRACT_ADDRESS, total: Object.keys(owners).length, holders: sortedHolders };

    await fs.writeFile('./js-scripts/hardhat/cvgCompensation/snapshotitos/cvgPepe-holders.json', JSON.stringify(output, null, 2));

    console.log(`\n✅ ${output.total} cvgPepe held by ${Object.keys(holders).length} addresses`);
}

main().catch(console.error);

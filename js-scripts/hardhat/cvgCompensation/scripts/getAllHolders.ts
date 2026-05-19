import fs from 'fs/promises';
import { CVX_REWARDS_CVG_ETH, TOPIC0_WITHDRAWN_CONVEX } from '../addresses';

const API_KEY = 'Y6R57JU6DIDE8HMWW4QEI3C9U5KXDTUQJ1';
const CONTRACT_ADDRESS = CVX_REWARDS_CVG_ETH;
const TOPIC0 = TOPIC0_WITHDRAWN_CONVEX;

const FROM_BLOCK = 19124399;
const TO_BLOCK = 20434300;
const STEP = 4000;
const SLEEP_MS = 400;

interface EtherscanLog {
    blockNumber: string;
    timeStamp: string;
    transactionHash: string;
    logIndex: string;
    transactionIndex: string;
    address: string;
    topics: string[];
    data: string;
}

async function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchLogs(fromBlock: number, toBlock: number, page: number = 1): Promise<EtherscanLog[]> {
    const url = `https://api.etherscan.io/v2/api` +
        `?module=logs` +
        `&action=getLogs` +
        `&chainid=1` +
        `&address=${CONTRACT_ADDRESS}` +
        `&topic0=${TOPIC0}` +
        `&fromBlock=${fromBlock}` +
        `&toBlock=${toBlock}` +
        `&apikey=${API_KEY}`;


    console.log(`Fetching blocks ${fromBlock} → ${toBlock} (page ${page})`);

    const response = await fetch(url);
    const data = await response.json();

    if (data.status === '0' && data.message === 'No records found') {
        return [];
    }

    if (data.status !== '1') {
        console.error('Etherscan error:', data.message);
        throw new Error(`API Error: ${data.message}`);
    }

    return data.result || [];
}

async function main() {
    const allLogs: EtherscanLog[] = [];
    let totalFetched = 0;

    console.log(`Starting fetch from ${FROM_BLOCK} to ${TO_BLOCK} with step ${STEP}...\n`);

    for (let start = FROM_BLOCK; start <= TO_BLOCK; start += STEP) {
        const end = Math.min(start + STEP - 1, TO_BLOCK);

        let page = 1;
        let hasMore = true;

        while (hasMore) {
            const logs = await fetchLogs(start, end, page);
            allLogs.push(...logs);
            totalFetched += logs.length;

            console.log(`  → Page ${page}: ${logs.length} logs (Total: ${totalFetched})`);

            if (logs.length < 1000) {
                hasMore = false;
            } else {
                page++;
                await sleep(300);
            }
        }

        if (start + STEP <= TO_BLOCK) {
            await sleep(SLEEP_MS);
        }
    }


    const output = {
        contract: CONTRACT_ADDRESS,
        fromBlock: FROM_BLOCK,
        toBlock: TO_BLOCK,
        totalLogs: allLogs.length,
        logs: allLogs
    };

    await fs.writeFile('./js-scripts/hardhat/cvgCompensation/snapshotitos/withdraw-logs-ConvexCRV-CVG-ETH.json', JSON.stringify(output, null, 2));

    console.log('\n✅ Terminé !');
    console.log(`Total de logs récupérés : ${allLogs.length}`);
    console.log('Fichier sauvegardé : transfer-logs.json');
}

// Lancement
main().catch(console.error);
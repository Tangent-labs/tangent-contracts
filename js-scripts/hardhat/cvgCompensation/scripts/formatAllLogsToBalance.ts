import { formatEther, ZeroAddress } from "ethers";
import fs from 'fs/promises';
import * as logsFile from "../logs/transfer-logs-stkCvgSdt.json";

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

// const addressesToRemove = [
//     "0xc8a6480ed7C7B1C401061f8d96bE7De6f94D3E60", // locking
//     "0x4b3Bd8906083bDE267A79E4131AF7a6f723960c8", // Staking
//     "0x865E59EBc3EE9EdD5656cD79b382f5153E466545", // Staking
//     "0xa7b0e924c2dbb9b4f576cce96ac80657e42c3e42", // LP
//     "0x004c167d27ada24305b76d80762997fa6eb8d9b2", // LP
//     "0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7", // DAO
//     "0xCD6cfCE8c8D3b6Efad27390e87D6931d4078B36c", // Airdrop
//     "0xC929bA60ef82fE55De3bC848dd9453B3b12a0c30", // Vesting
//     "0x2191df768ad71140f9f3e96c1e4407a4aa31d082", // cvgCVX
//     "0x794C31863B0459039B17479dC638c1948c27FcB9", // Team,
//     "0x46cB1982abeb3df9D92DCC678629C11239cA0BBE", // Bootstraping module
// ].map((addr) => addr.toLowerCase());

async function main() {

    const allLogs: EtherscanLog[] = logsFile!.logs as EtherscanLog[];
    const balances: { [address: string]: bigint | string } = {};

    for (let index = 0; index < allLogs.length; index++) {
        const log = allLogs[index];

        const from = `0x${log.topics[1].slice(26)}`;
        const to = `0x${log.topics[2].slice(26)}`;

        const amount = BigInt(log.data)


        if (!balances[from]) {
            balances[from] = 0n;
        }

        if (!balances[to]) {
            balances[to] = 0n;
        }

        if (from === ZeroAddress) {
            (balances[to] as bigint) += amount;
        } else if (to === ZeroAddress) {
            (balances[from] as bigint) -= amount;
        } else {
            (balances[from] as bigint) -= amount;
            (balances[to] as bigint) += amount;
        }
    }

    Object.entries(balances).forEach(([addr, bal]) => {
        if (bal === 0n) {
            delete balances[addr];
        }
        // if (addressesToRemove.includes(addr)) {
        //     delete balances[addr];
        // }
    });

    const finalResults = Object.entries(balances).map(([k, v]) => {
        return { address: k, balance: v.toString() };
    }).sort((a, b) => Number(formatEther(b.balance)) - Number(formatEther(a.balance)))

    await fs.writeFile('./js-scripts/hardhat/cvgCompensation/snapshotitos/snapshot-stkCvgSdt-balances.json', JSON.stringify(finalResults, null, 2));

    console.log('\n✅ Terminé !');
    console.log(`Total de logs récupérés : ${allLogs.length}`);
    console.log('Fichier sauvegardé : transfer-logs.json');
}

// Lancement
main().catch(console.error);


import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/types";
dotenv.config();


const forkBloc = process.env.STARTING_BLOCK ? parseInt(process.env.STARTING_BLOCK) : 24770812;
const forkRpc = process.env.FORK_RPC ||` https://eth-mainnet.g.alchemy.com/v2/zCrDEsqvlSdKaF_Tv0q4Q`;

 const config: HardhatUserConfig = {
    solidity: "0.8.28",
    networks: {
        localhost: {
            chainId: 31337, 
            url: "http://127.0.0.1:8545",
            forking: {
                url: forkRpc,
                blockNumber: forkBloc,
            },
            timeout: 100_000_000,
        },
        hardhat: {
            mining: {
                auto: true,
                interval: 12_000,
            },
            forking: {
                url: forkRpc,
                blockNumber: forkBloc,
            },
        },
    }
};

console.log({forkBloc, forkRpc});
export default config;
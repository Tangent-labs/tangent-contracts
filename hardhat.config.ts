import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-vyper";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";

import * as dotenv from "dotenv";
dotenv.config();


const forkBloc = 25651999; // process.env.STARTING_BLOCK ? parseInt(process.env.STARTING_BLOCK) : 24770812;
const forkRpc = process.env.FORK_RPC || `https://eth-mainnet.g.alchemy.com/v2/zCrDEsqvlSdKaF_Tv0q4Q`;

const config: HardhatUserConfig = {
    vyper: {
        version: "0.3.10",
    },

    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    },
    solidity: {
        compilers: [
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "cancun",
                },
            },
        ],
    },
    networks: {
        localhost: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "http://127.0.0.1:8545",
            // mining: {
            //     auto: false,
            //     interval: 12_000,
            // },
            // accounts: {
            //     mnemonic: "test test test test test test test test test test test junk",
            //     count: 300, // 👈 get as many as you want
            //     path: "m/44'/60'/0'/0",
            // },
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

        mainnet: {
            url: forkRpc,
            accounts: [process.env.PRIVATE_KEY!]
        },
        tangent: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "https://rpc.tangent.finance",
            timeout: 100_000_000,
        },
        staging: {
            chainId: 31337,
            url: "https://rpc.tangent.finance",
            timeout: 100_000_000,
        },
    },
    paths: {
        cache: "cache_hardhat", // ← FORCE LE DOSSIER
    },
};

export default config;

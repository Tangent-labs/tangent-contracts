import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ethers";
import "@nomiclabs/hardhat-vyper";
import "hardhat-contract-sizer";

import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
    vyper: {
        version: "0.3.10",
    },

    etherscan: {
        apiKey: {
            // Is not required by blockscout. Can be any non-empty string
            localhost: "abc",
        },
        customChains: [
            {
                network: "localhost",
                chainId: 31337,
                urls: {
                    apiURL: process.env.BLOCKSCOUT_HOST_HTTP + ":80/api",
                    browserURL: process.env.BLOCKSCOUT_HOST_HTTP + ":80",
                },
            },
        ],
    },
    solidity: {
        compilers: [
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                },
            },
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
    // NOTE : Block exploit CVG :20_434_300
    networks: {
        localhost: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "http://127.0.0.1:8545",
            mining: {
                auto: true,
                interval: 12_000,
            },
            forking: {
                url: `https://mainnet.infura.io/v3/ae4b64bed2884c5c87b4acbb4f062682`,
                blockNumber: 20434300,
            },
            timeout: 100_000_000,
        },
        hardhat: {
            mining: {
                auto: true,
                interval: 12_000,
            },
            forking: {
                url: `https://mainnet.infura.io/v3/ae4b64bed2884c5c87b4acbb4f062682`,
                blockNumber: 20434300,
            },
        },
        tangent: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "http://176.143.254.58:8545",
            timeout: 100_000_000,
        },
        staging: {
            chainId: 31337,
            url: "https://io.convergence-finance.network:8545",
            timeout: 100_000_000,
        },
    },
    paths: {
        cache: "cache_hardhat",  // ← FORCE LE DOSSIER
    },
};

export default config;

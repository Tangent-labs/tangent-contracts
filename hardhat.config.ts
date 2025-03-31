import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomiclabs/hardhat-vyper";
import * as dotenv from "dotenv";
dotenv.config();
const forkBlock = 22030297;
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
                        runs: 250,
                    },
                },
            },
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 250,
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
            //     auto: true,
            //     interval: 5000,
            // },
            forking: {
                url: `https://eth-mainnet.g.alchemy.com/v2/hDva-MsYmcDn3GhDTeMYHq4iKLiT1NYy`,
                blockNumber: forkBlock,
            },
            timeout: 100_000_000,
        },
        // hardhat: {
        //     // mining: {
        //     //     auto: true,
        //     //     interval: 5000,
        //     // },
        //     forking: {
        //         url: `https://eth-mainnet.g.alchemy.com/v2/hDva-MsYmcDn3GhDTeMYHq4iKLiT1NYy`,
        //         blockNumber: forkBlock,
        //     },
        //     timeout: 100_000_000,
        // },
        tangent: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "https://io.convergence-finance.network:8545",
            timeout: 100_000_000,
        },
    },
};

export default config;

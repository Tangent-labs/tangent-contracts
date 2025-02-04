import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-ignition-ethers";
import {EndpointId} from "@layerzerolabs/lz-definitions";

const forkBlock = 21771693;
const config: HardhatUserConfig = {
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
            forking: {
                url: `https://eth-mainnet.g.alchemy.com/v2/hDva-MsYmcDn3GhDTeMYHq4iKLiT1NYy`,
                blockNumber: forkBlock,
            },
            timeout: 100_000_000,
        },
        hardhat: {
            forking: {
                url: `https://eth-mainnet.g.alchemy.com/v2/hDva-MsYmcDn3GhDTeMYHq4iKLiT1NYy`,
                blockNumber: forkBlock,
            },
        },
        tangent: {
            chainId: 31337, // Chain ID should match the hardhat network's chainid
            url: "https://io.convergence-finance.network:8545",
            timeout: 100_000_000,
        },
        "avalanche-fuji": {
            eid: EndpointId.AVALANCHE_V2_TESTNET,
            chainId: 43113,
            url: "https://rpc.ankr.com/avalanche_fuji",
            timeout: 100_000_000,
        },
        "polygon-amoy": {
            eid: EndpointId.AMOY_V2_TESTNET,
            chainId: 80002,
            url: "https://polygon-amoy-bor-rpc.publicnode.com",
            timeout: 100_000_000,
        },
    },
};

export default config;

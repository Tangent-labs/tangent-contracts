import {
    CHAINLINK_PRICE_FEEDS,
    CURVE_LPS,
    REDSTONE_PRICE_FEEDS
} from "@tangent/defi-resources";
import "dotenv/config";
import { ethers } from "ethers";
import { PROD_ADDRESSES } from "../../../ignition/prod_addresses";


export async function main() {
    const rpcUrl = "https://eth-mainnet.g.alchemy.com/v2/zCrDEsqvlSdKaF_Tv0q4Q";
    const privateKey = process.env.PRIVATE_KEY!;

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);

    const abiRedstone = await import("../../../artifacts/src/USG/Oracles/Token/OracleRedstoneWrapperFallback.sol/OracleRedstoneWrapperFallback.json")
    const abiChainlink = await import("../../../artifacts/src/USG/Oracles/Token/OracleChainlinkWrapper.sol/OracleChainlinkWrapper.json")
    const abiDuoPool = await import("../../../artifacts/src/USG/Oracles/CurveLP/OracleDuoPoolStable.sol/OracleDuoPoolStable.json")

    // Factories (ethers-only)
    const redstoneFactory = new ethers.ContractFactory(abiRedstone.abi, abiRedstone.bytecode, wallet);
    const chainlinkFactory = new ethers.ContractFactory(abiChainlink.abi, abiChainlink.bytecode, wallet);
    const duoPoolFactory = new ethers.ContractFactory(abiDuoPool.abi, abiDuoPool.bytecode, wallet);


    // ----------------------------
    // Deploy Redstone fallback
    // ----------------------------
    const pyUSDRedstoneFallback = await redstoneFactory.deploy(
        REDSTONE_PRICE_FEEDS.PYUSD_USD,
        "Fallback PYUSD/USD"
    );
    await pyUSDRedstoneFallback.waitForDeployment();

    // ----------------------------
    // Chainlink oracle
    // ----------------------------
    const PYUSDChainlinkOracle = await chainlinkFactory.deploy(
        CHAINLINK_PRICE_FEEDS.PYUSD_USD,
        86400,
        await pyUSDRedstoneFallback.getAddress(),
        "PYUSD/USD"
    );
    await PYUSDChainlinkOracle.waitForDeployment();

    // ----------------------------
    // Duo pool oracle
    // ----------------------------
    const PYUSD_USDC_Oracle = await duoPoolFactory.deploy(
        CURVE_LPS.DUO_PYUSD_USDC,
        await PYUSDChainlinkOracle.getAddress(),
        PROD_ADDRESSES.ORACLES.CHAINLINK.USDC,
        "PYUSD_USDC/USD"
    );
    await PYUSD_USDC_Oracle.waitForDeployment();

    console.log({
        pyUSDRedstoneFallback: await pyUSDRedstoneFallback.getAddress(),
        PYUSDChainlinkOracle: await PYUSDChainlinkOracle.getAddress(),
        PYUSD_USDC_Oracle: await PYUSD_USDC_Oracle.getAddress()
    });
}

main().catch(console.error);
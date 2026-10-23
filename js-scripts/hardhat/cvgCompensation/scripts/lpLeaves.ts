import { formatEther, ZeroAddress } from "ethers";
import fs from 'fs/promises';
import { ethers } from "hardhat";
import { CVX_REWARDS_CVG_ETH, CVX_REWARDS_CVG_FRAXBP, CVXFRAX_STAKING_WRAPPER_CVG_FRAXBP, STAKEDAO_GAUGE_CVG_FRAXBP } from "../addresses";
import * as cvxEthDeposits from "../logs/deposits-logs-ConvexCRV-CVG-ETH.json";
import * as cvxFraxBpDeposits from "../logs/deposits-logs-ConvexCRV-CVG-FRAXBP.json";
import * as fraxWrapperTransfers from "../logs/transfer-logs-FraxWrapper-CVG-FRAXBP.json";
import * as sdEthTransfers from "../logs/transfer-logs-StakeDao-CVG-ETH-LP.json";
import * as sdFraxBpTransfers from "../logs/transfer-logs-StakeDao-CVG-FRAXBP.json";
import * as cvxEthWithdraws from "../logs/withdraw-logs-ConvexCRV-CVG-ETH.json";
import * as cvxFraxBpWithdraws from "../logs/withdraws-logs-ConvexCRV-CVG-FRAXBP.json";

// Run with STARTING_BLOCK=20434300 (snapshot block, exploit at 20434450)
// Resolves the LP positions that are not plain ERC20 balances down to the final user.

const STAKEDAO_GAUGE_CVG_ETH = "0xd79d3329560489835265D4d100583f21AC9C4A3e"
const FRAX_FARM_CVG_FRAXBP = "0x1ee8d379e374a4a00e7d79af4bf2ed2b591561c2"

type Log = { topics: string[]; data: string }
const topicToAddress = (t: string) => `0x${t.slice(26)}`

async function write(fileName: string, balances: { [address: string]: bigint }) {
    const finalResults = Object.entries(balances)
        .filter(([, v]) => v !== 0n)
        .map(([k, v]) => ({ address: k.toLowerCase(), balance: v.toString() }))
        .sort((a, b) => Number(formatEther(b.balance)) - Number(formatEther(a.balance)))
    await fs.writeFile(`./js-scripts/hardhat/cvgCompensation/snapshotitos/${fileName}.json`, JSON.stringify(finalResults, null, 2));
}

// Replaying StakeDAO Transfer logs gives wrong balances, so query balanceOf at the fork block for every address seen in the logs
async function balancesAtBlock(token: string, logs: Log[]) {
    const erc20 = await ethers.getContractAt(["function balanceOf(address) view returns (uint256)"], token)
    const addresses = new Set(logs.flatMap(l => [topicToAddress(l.topics[1]), topicToAddress(l.topics[2])]))
    addresses.delete(ZeroAddress)
    const balances: { [address: string]: bigint } = {}
    for (const address of addresses) {
        balances[address] = await erc20.balanceOf(address)
    }
    return balances
}

// Convex BaseRewardPool : Staked(user, amount) - Withdrawn(user, amount)
function convexNet(deposits: Log[], withdraws: Log[]) {
    const balances: { [address: string]: bigint } = {}
    deposits.forEach(l => balances[topicToAddress(l.topics[1])] = (balances[topicToAddress(l.topics[1])] ?? 0n) + BigInt(l.data))
    withdraws.forEach(l => balances[topicToAddress(l.topics[1])] = (balances[topicToAddress(l.topics[1])] ?? 0n) - BigInt(l.data))
    return balances
}

async function main() {
    await write("snapshot-StakeDao-CVG-ETH-LP", await balancesAtBlock(STAKEDAO_GAUGE_CVG_ETH, sdEthTransfers.logs as Log[]))
    await write("snapshot-StakeDao-CVG-FRAXBP-LP", await balancesAtBlock(STAKEDAO_GAUGE_CVG_FRAXBP, sdFraxBpTransfers.logs as Log[]))

    const cvxEth = convexNet(cvxEthDeposits.logs as Log[], cvxEthWithdraws.logs as Log[])
    const cvxFraxBp = convexNet(cvxFraxBpDeposits.logs as Log[], cvxFraxBpWithdraws.logs as Log[])
    for (const [rewards, balances] of [[CVX_REWARDS_CVG_ETH, cvxEth], [CVX_REWARDS_CVG_FRAXBP, cvxFraxBp]] as const) {
        const pool = await ethers.getContractAt(["function balanceOf(address) view returns (uint256)"], rewards)
        for (const [address, amount] of Object.entries(balances)) {
            if (amount !== await pool.balanceOf(address)) throw new Error(`Convex mismatch ${rewards} ${address}`)
        }
    }
    await write("snapshot-Convex-CVG-ETH", cvxEth)
    await write("snapshot-Convex-CVG-FRAXBP", cvxFraxBp)

    // Convex-Frax : wrapper tokens are either in wallets or locked in the Frax farm by a per-user vault (owner())
    const wrapper = await ethers.getContractAt(["function balanceOf(address) view returns (uint256)"], CVXFRAX_STAKING_WRAPPER_CVG_FRAXBP)
    const farm = await ethers.getContractAt(["function lockedLiquidityOf(address) view returns (uint256)"], FRAX_FARM_CVG_FRAXBP)
    const fraxHolders: { [address: string]: bigint } = {}
    const seen = new Set((fraxWrapperTransfers.logs as Log[]).flatMap(l => [topicToAddress(l.topics[1]), topicToAddress(l.topics[2])]))
    seen.delete(ZeroAddress)
    seen.delete(FRAX_FARM_CVG_FRAXBP)
    for (const address of seen) {
        const amount = (await wrapper.balanceOf(address)) + (await farm.lockedLiquidityOf(address))
        if (amount === 0n) continue
        let owner = address
        try {
            owner = (await (await ethers.getContractAt(["function owner() view returns (address)"], address)).owner()).toLowerCase()
        } catch (e) { } // EOA staking directly
        fraxHolders[owner] = (fraxHolders[owner] ?? 0n) + amount
    }
    await write("snapshot-FraxConvex-CVG-FRAXBP", fraxHolders)
}

main().catch(console.error);

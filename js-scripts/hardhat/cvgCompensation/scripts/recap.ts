import assert from "assert";
import { formatEther } from "ethers";
import fs from "fs";

// Per-address recap of the CVG compensation (rules : cvg-compensation-snapshot.csv)
// Snapshot block 20434300, exploit at 20434450. All snapshotitos files are computed at that block.
// npx ts-node --transpile-only js-scripts/hardhat/cvgCompensation/scripts/recap.ts

const DIR = `${__dirname}/../snapshotitos`
const read = (file: string): any[] => JSON.parse(fs.readFileSync(`${DIR}/${file}.json`, "utf8"))

// Protocol owned LP, excluded from LP sources
const POD: string[] = [
    "0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb", // Convergence POL Safe (Convex, StakeDAO, Convex-Frax)
].map((a: string) => a.toLowerCase());

// Contracts holding LP on behalf of users, their users are counted in the downstream snapshot
const INTERMEDIARIES = [
    "0x004c167d27ada24305b76d80762997fa6eb8d9b2", // CVG-ETH pool
    "0xa7b0e924c2dbb9b4f576cce96ac80657e42c3e42", // CVG-FRAXBP pool
    "0x16a3a047fc1d388d5846a73acdb475b11228c299", // Curve gauge CVG-ETH
    "0x8a111b47b31bba40c2f0d2f9a8cf6b6c4b50114e", // Curve gauge CVG-FRAXBP
    "0x989aeb4d175e16225e39e87d0d97a3360524ad80", // Convex voter proxy
    "0x52f541764e6e90eebc5c21ff570de0e2d63766b6", // StakeDAO Curve locker
    "0x7b61b1a0ceda2f01f33be885a3a34c95b38ad118", // StakeDAO Convex sidecar CVG-ETH
    "0x21777106355ba506a31ff7984c0ae5c924deb77f", // CVG SdtBlackhole -> lp-staked-in-cvg
    "0x7b465174a93a6d0602fd4ea99eec86c07e5e1568", // Convex-Frax staking wrapper CVG-FRAXBP
    "0x1ee8d379e374a4a00e7d79af4bf2ed2b591561c2", // Frax farm CVG-FRAXBP
]

// Non user contracts holding CVG, excluded from Holders (Safes / smart wallets are kept)
const INFRA = [
    "0x0000000895cb182e6f983eb4d8b4e0aa0b31ae4c", // StakeDAO Votemarket Platform (bribes)
    "0xadfbfd06633eb92fc9b58b3152fe92b0a24eb1ff", // StakeDAO Votemarket Botmarket
    "0xbed58c1053fd347843883eade0781f562a66f623", // Curve TricryptoOptimizedWETH pool
    "0xb911fcce8d5afcec73e072653107260bb23c1ee8", // Curve FeeBurner
    "0x97effb790f2fbb701d88f89db4521348a2b77be8", // CVG token
    "0x9008d19f58aabd9ed0d60971565aa8510560ab41", // CoW GPv2Settlement
    "0xe9b52a6658bece967c910411a28ef7544e62933e", // DODO DVM pool
    "0xb634316e06cc0b358437cbadd4dc94f1d3a92b3b", // TradeHandler
    "0xe4000004000bd8006e00720000d27d1fa000d43e", // MEV bot
    "0x1111111254eeb25477b68fb85ed929f73a960582", // 1inch router
]

// Curve pool state at block 20434300
const LP = {
    eth: { cvg: 1709066327912816286498822n, supply: 10271684211598307586111n },
    fraxbp: { cvg: 144983002550008978552127n, supply: 47954309179326620099993n },
}

const COLUMNS = ["holders", "lockers", "stakers", "seed", "wl", "ibo", "bonds", "lpEthCvg", "lpFraxbpCvg"] as const
type Column = typeof COLUMNS[number]

const recap: { [address: string]: { [c in Column]: bigint } } = {}
const add = (column: Column, address: string, amount: bigint) => {
    assert(amount >= 0n, `negative ${column} ${address}`)
    const a = address.toLowerCase()
    recap[a] ??= Object.fromEntries(COLUMNS.map(c => [c, 0n])) as any
    recap[a][column] += amount
}
const sumOf = (rows: any[], key = "balance") => rows.reduce((s, r) => s + BigInt(r[key]), 0n)

// Holders
read("cvg-balances").filter(r => !INFRA.includes(r.address.toLowerCase())).forEach(r => add("holders", r.address, BigInt(r.balance)))
read("lockers").forEach(r => add("lockers", r.address, BigInt(r.value)))
read("bonds").forEach(r => add("bonds", r.address, BigInt(r.value)))
const stakers = [...read("stkCvgEth-balances"), ...read("stkCvgSdt-balances")]
stakers.forEach(r => add("stakers", r.address, BigInt(r.balance)))

// Investors : seed counts the initial value, WL & IBO only what was still unclaimed
read("seed").forEach(r => add("seed", r.address, BigInt(r.values.bought)))
read("wl").forEach(r => add("wl", r.address, BigInt(r.values.bought) - BigInt(r.values.claimed)))
read("ibo").forEach(r => add("ibo", r.address, BigInt(r.values.bought) - BigInt(r.values.claimed)))

// LPs : every integration layer an LP can sit in, intermediaries removed, then converted to CVG in the pool
const LAYERS = ["curveLp", "curveGauge", "convex", "convexFrax", "stakeDao", "cvgStaking"] as const
type Layer = typeof LAYERS[number]
const lpRecap: { [key: string]: { address: string; pool: string; pod: boolean } & { [l in Layer]: bigint } } = {}
const lpSum = (file: string) => sumOf(read(file).map(r => ({ balance: r.balance ?? r.value })))
const lpOf = (file: string, address: string) => BigInt(read(file).find(r => r.address.toLowerCase() === address)?.balance ?? 0)

function addLp(column: Column, pool: { cvg: bigint; supply: bigint }, layers: { [l in Layer]?: string }) {
    let leaves = 0n, pod = 0n
    for (const [layer, file] of Object.entries(layers) as [Layer, string][]) {
        for (const r of read(file)) {
            const address = r.address.toLowerCase()
            const lp = BigInt(r.balance ?? r.value)
            if (INTERMEDIARIES.includes(address)) continue
            const isPod = POD.includes(address)
            const key = `${address}-${column}`
            lpRecap[key] ??= { address, pool: column, pod: isPod, ...Object.fromEntries(LAYERS.map(l => [l, 0n])) as any }
            lpRecap[key][layer] += lp
            if (isPod) { pod += lp; continue }
            leaves += lp
            add(column, address, lp * pool.cvg / pool.supply)
        }
    }
    // every LP token is accounted exactly once
    assert.equal(leaves + pod, pool.supply, `${column} LP leaves do not match supply`)
}

// Each layer sums exactly to what its parent holds in the layer above
const ETH_LAYERS = {
    curveLp: "snapshot-CVG-ETH-LP-balances", curveGauge: "snapshot-CrvGauge-CVG-ETH-balances", convex: "snapshot-Convex-CVG-ETH",
    stakeDao: "snapshot-StakeDao-CVG-ETH-LP", cvgStaking: "lp-staked-in-cvg",
}
const FRAXBP_LAYERS = {
    curveLp: "snapshot-CVG-FRAXBP-LP-balances", curveGauge: "snapshot-CrvGauge-CVG-FRAXBP-LP-balances", convex: "snapshot-Convex-CVG-FRAXBP",
    convexFrax: "snapshot-FraxConvex-CVG-FRAXBP", stakeDao: "snapshot-StakeDao-CVG-FRAXBP-LP",
}
const [GAUGE_ETH, GAUGE_FRAXBP, CVX_PROXY, SD_LOCKER, SD_SIDECAR, SDT_BLACKHOLE, CVXFRAX_WRAPPER] = INTERMEDIARIES.slice(2, 9)
assert.equal(lpSum(ETH_LAYERS.curveLp), LP.eth.supply)
assert.equal(lpSum(ETH_LAYERS.curveGauge), lpOf(ETH_LAYERS.curveLp, GAUGE_ETH))
assert.equal(lpSum(ETH_LAYERS.convex), lpOf(ETH_LAYERS.curveGauge, CVX_PROXY))
assert.equal(lpSum(ETH_LAYERS.stakeDao), lpOf(ETH_LAYERS.curveGauge, SD_LOCKER) + lpOf(ETH_LAYERS.convex, SD_SIDECAR))
assert.equal(lpSum(ETH_LAYERS.cvgStaking), lpOf(ETH_LAYERS.stakeDao, SDT_BLACKHOLE))
assert.equal(lpSum(FRAXBP_LAYERS.curveLp), LP.fraxbp.supply)
assert.equal(lpSum(FRAXBP_LAYERS.curveGauge), lpOf(FRAXBP_LAYERS.curveLp, GAUGE_FRAXBP))
assert.equal(lpSum(FRAXBP_LAYERS.convex), lpOf(FRAXBP_LAYERS.curveGauge, CVX_PROXY))
assert.equal(lpSum(FRAXBP_LAYERS.convexFrax), lpOf(FRAXBP_LAYERS.convex, CVXFRAX_WRAPPER))
assert.equal(lpSum(FRAXBP_LAYERS.stakeDao), lpOf(FRAXBP_LAYERS.curveGauge, SD_LOCKER))

addLp("lpEthCvg", LP.eth, ETH_LAYERS)
addLp("lpFraxbpCvg", LP.fraxbp, FRAXBP_LAYERS)

// Source totals checked onchain at block 20434300
const total = (c: Column) => Object.values(recap).reduce((s, r) => s + r[c], 0n)
assert.equal(total("stakers"), 970184941673050220100016n + 425384451692052112850646n, "stakers != stkCVG supplies")
assert.equal(total("bonds"), 72880665161628786342958n, "bonds != claimable + pending")
assert.equal(total("lockers"), sumOf(read("lockers"), "value"))

// Tokens : 1 CVG = 1 token, LP CVG = 2 tokens
// Addresses under 1 token are dust, removed before the TAN pro rata
const MIN_TOKENS = 10n ** 18n
const tokens = (r: { [c in Column]: bigint }) => COLUMNS.reduce((s, c) => s + (c.startsWith("lp") ? 2n : 1n) * r[c], 0n)
const rows = Object.entries(recap)
    .map(([address, r]) => ({ address, ...r, totalTokens: tokens(r) }))
    .filter(r => r.totalTokens >= MIN_TOKENS)
    .sort((a, b) => (b.totalTokens > a.totalTokens ? 1 : -1))

// TAN : 15% of the 10M supply, shared pro rata of the tokens (points)
const TAN_AIRDROP = 10_000_000n * 10n ** 18n * 15n / 100n
const totalPoints = rows.reduce((s, r) => s + r.totalTokens, 0n)
const tanRows = rows.map(r => ({ ...r, tan: r.totalTokens * TAN_AIRDROP / totalPoints }))
const tanDistributed = tanRows.reduce((s, r) => s + r.tan, 0n)
// floor rounding leaves less than 1 wei per address undistributed
assert(tanDistributed <= TAN_AIRDROP && TAN_AIRDROP - tanDistributed < BigInt(rows.length), "TAN distribution does not match the airdrop")

const header = ["address", ...COLUMNS, "totalTokens", "tan"] as const
fs.writeFileSync(`${__dirname}/../results/recap.json`, JSON.stringify(tanRows.map(r => Object.fromEntries(header.map(h => [h, h === "address" ? r.address : r[h].toString()]))), null, 2))

// LP breakdown per owner, per pool, per integration layer (LP units), POD rows kept but flagged
const lpRows = Object.values(lpRecap).map(r => {
    const pool = r.pool === "lpEthCvg" ? LP.eth : LP.fraxbp
    const totalLp = LAYERS.reduce((s, l) => s + r[l], 0n)
    const cvg = totalLp * pool.cvg / pool.supply
    return { ...r, pool: r.pool === "lpEthCvg" ? "CVG-ETH" : "CVG-FRAXBP", totalLp, cvg }
}).sort((a, b) => a.pool.localeCompare(b.pool) || (b.totalLp > a.totalLp ? 1 : -1))
fs.writeFileSync(`${__dirname}/../results/lp-recap.json`, JSON.stringify(lpRows.map(r => ({
    address: r.address, pool: r.pool, ...Object.fromEntries(LAYERS.map(l => [l, r[l].toString()])),
    totalLp: r.totalLp.toString(), cvgInLp: r.cvg.toString(), tokens: r.pod ? "0" : (2n * r.cvg).toString(),
    status: r.pod ? "excluded (POD)" : "counted",
})), null, 2))

console.log(`${rows.length} addresses, ${formatEther(totalPoints)} tokens, ${formatEther(tanDistributed)} TAN (dust ${TAN_AIRDROP - tanDistributed} wei)`)
COLUMNS.forEach(c => console.log(`  ${c.padEnd(12)} ${formatEther(total(c))} CVG`))
if (!POD.length) console.warn("⚠️  POD list is empty, protocol owned LP is counted")

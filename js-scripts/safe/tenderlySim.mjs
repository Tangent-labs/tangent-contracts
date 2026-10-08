// Prints the execTransaction calldata of a Safe tx + what to fill in Tenderly's simulator UI.
// Usage: node js-scripts/safe/tenderlySim.mjs <safeTxHash> [chain=eth] [rpcUrl]
import { Interface, JsonRpcProvider, concat } from "ethers";

const [safeTxHash, chain = "eth", rpcUrl = "https://ethereum-rpc.publicnode.com"] = process.argv.slice(2);
if (!safeTxHash) {
    console.error("Usage: node js-scripts/safe/tenderlySim.mjs <safeTxHash> [chain=eth] [rpcUrl]");
    process.exit(1);
}

const res = await fetch(`https://api.safe.global/tx-service/${chain}/api/v1/multisig-transactions/${safeTxHash}/`);
if (!res.ok) throw new Error(`Safe API ${res.status}: ${await res.text()}`);
const tx = await res.json();

// Safe requires signatures sorted by owner address ascending
const sigs = [...tx.confirmations].sort((a, b) => (BigInt(a.owner) < BigInt(b.owner) ? -1 : 1));

const safeIface = new Interface([
    "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns (bool)",
    "function nonce() view returns (uint256)",
]);
const calldata = safeIface.encodeFunctionData("execTransaction", [
    tx.to,
    tx.value,
    tx.data ?? "0x",
    tx.operation,
    tx.safeTxGas,
    tx.baseGas,
    tx.gasPrice,
    tx.gasToken,
    tx.refundReceiver,
    concat(sigs.map((c) => c.signature)),
]);
const from = sigs[0]?.owner ?? tx.proposer;

const provider = new JsonRpcProvider(rpcUrl);
const [onchainNonce] = safeIface.decodeFunctionResult("nonce", await provider.call({ to: tx.safe, data: safeIface.encodeFunctionData("nonce") }));
let dryRun;
try {
    await provider.call({ to: tx.safe, from, data: calldata });
    dryRun = "OK";
} catch (e) {
    dryRun = `REVERT ${e.shortMessage ?? e.message}`;
}

const describe = (d) => (d?.dataDecoded ? `${d.dataDecoded.method}(...)` : d?.data?.slice(0, 10) ?? "0x");
console.log(`
=== Safe tx ${tx.safeTxHash} ===
Safe:          ${tx.safe}
Nonce:         ${tx.nonce} (on-chain: ${onchainNonce})${tx.isExecuted ? "  [ALREADY EXECUTED]" : ""}
Confirmations: ${tx.confirmations.length}/${tx.confirmationsRequired}
Target:        ${tx.to} ${tx.operation === 1 ? "(DELEGATECALL)" : "(CALL)"} -> ${describe(tx)}`);
for (const sub of tx.dataDecoded?.parameters?.[0]?.valueDecoded ?? []) {
    console.log(`  - ${sub.operation === 1 ? "delegatecall" : "call"} ${sub.to} value=${sub.value} ${describe(sub)}  ${sub.data}`);
}
console.log(`Dry run (eth_call @ latest): ${dryRun}

=== Tenderly > Simulator > New Simulation ===
Network:            ${chain === "eth" ? "Ethereum Mainnet" : chain}
From:               ${from}
To (contract):      ${tx.safe}
Input:              "Enter raw input data" -> paste Raw input data below
Value:              0
Block:              latest (or pin one)
Gas:                default (or 3,000,000)

Raw input data:
${calldata}
`);
if (tx.confirmations.length < tx.confirmationsRequired) {
    console.log(`WARNING: only ${tx.confirmations.length}/${tx.confirmationsRequired} signatures; will revert (GS020/GS026) unless you override threshold (storage slot 4) in Tenderly state overrides.`);
}

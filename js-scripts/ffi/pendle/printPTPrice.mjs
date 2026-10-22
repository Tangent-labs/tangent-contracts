// Prints the ABI-encoded USD price of a Pendle PT (18 decimals) from the Pendle API.
// Usage: node printPTPrice.mjs <chainId> <market>
import {AbiCoder, parseUnits} from "ethers";

const [chainId, market] = process.argv.slice(2);

const res = await fetch(`https://api-v2.pendle.finance/core/v1/${chainId}/markets/${market}`);
if (!res.ok) throw new Error(`Pendle API ${res.status}`);
const {pt} = await res.json();

// ABI-encoded so vm.ffi returns raw bytes (a digit-only string would be hex-decoded)
process.stdout.write(AbiCoder.defaultAbiCoder().encode(["uint256"], [parseUnits(pt.price.usd.toFixed(18), 18)]));

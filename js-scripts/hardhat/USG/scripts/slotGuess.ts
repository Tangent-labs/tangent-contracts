// { amount: 1000000000, name: 'crvUSD_ETH_CRV' },
// { amount: 1000000000, name: 'GHO_cbBTC_WETH' },
// { amount: 1000000000, name: 'USDT_WBTC_WETH' },
// { amount: 1000000000, name: 'USR_RLP' },
// { amount: 1000000000, name: 'USDe_27_11_25' },
// { amount: 1000000000, name: 'sUSDe_27_11_25' },

import { PENDLE_POOLS } from "@tangent/defi-resources";
import { CRV_DUO_USR_RLP, CRV_TRI_CRYPTO_USDT, CRV_TRI_GHO_cbBTC_ETH, TRI_crvUSD_ETH_CRV } from "@tangent/defi-resources/build/ressources/lps/curve";
import { getSlot } from "../../thief/slotGuesser";

const tokens = [
    { name: "crvUSD_ETH_CRV", address: "0x48d670d189b4b48757992d36897bca6e3f889040", isVyper: true },

];

async function main() {
    const result = await getSlot(tokens);
    console.log(result);
    for (const token of tokens) {
        console.log(token.name, result.find((t) => t.token === token.address)?.slot, `name : ${token.name}`);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

import {COMMON_ERC20S, ConvexFxnPools, CURVE_LPS} from "@tangent/defi-resources";
import {getSlot} from "../../thief/slotGuesser";

const LIQUIDATION_TOKENS = [
    {name: "RLUSD", address: COMMON_ERC20S.RLUSD},
    {name: "USDC_fxUSD", address: ConvexFxnPools.USDC_fxUSD.lpToken},
    {name: "fxUSD_reUSD", address: CURVE_LPS.DUO_fxUSD_reUSD},
    {name: "PYUSD_USDC", address: CURVE_LPS.DUO_PYUSD_USDC},
    {name: "RLUSD_USDC", address: CURVE_LPS.DUO_RLUSD_USDC},
    {name: "frxUSD_sUSDS", address: CURVE_LPS.DUO_frxUSD_sUSDS},
    {name: "BOLD_USDC", address: CURVE_LPS.DUO_BOLD_USDC},
    {name: "eUSD_USDC", address: CURVE_LPS.DUO_eUSD_USDC},
    {name: "scrvUSD_sUSDe", address: CURVE_LPS.DUO_scrvUSD_sUSDe},
    {name: "USDT_crvUSD", address: CURVE_LPS.DUO_USDT_crvUSD},
    {name: "frxUSD_OUSD", address: CURVE_LPS.DUO_frxUSD_OUSD},
    {name: "frxUSD_sDOLA", address: CURVE_LPS.DUO_frxUSD_sDOLA},
    {name: "frxUSD_scrvUSD", address: CURVE_LPS.DUO_frxUSD_scrvUSD},
].filter((token) => Boolean(token.address));

function renderThiefConfigEntry(row: Awaited<ReturnType<typeof getSlot>>[number]) {
    return `    ${row.name}: {
        address: "${row.token}",
        slotBalance: ${row.slot},
        decimals: ${row.decimals?.toString() || 18},
        isVyper: ${row.isVyper},
    },`;
}

async function main() {
    const maxSlot = Number(process.env.MAX_SLOT || 100);
    const rows = await getSlot(LIQUIDATION_TOKENS, maxSlot);
    const found = rows.filter((row) => row.slot >= 0);
    const missing = rows.filter((row) => row.slot < 0);

    console.table(
        rows.map((row) => ({
            key: row.name,
            address: row.token,
            symbol: row.symbol,
            decimals: row.decimals?.toString(),
            slotBalance: row.slot,
            isVyper: row.isVyper,
        }))
    );

    if (missing.length) {
        console.log("\nMissing slots:");
        for (const row of missing) {
            console.log(`- ${row.name}: ${row.token}`);
        }
    }

    console.log("\nTHIEF_TOKEN_CONFIG entries:");
    for (const row of found) {
        console.log(renderThiefConfigEntry(row));
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

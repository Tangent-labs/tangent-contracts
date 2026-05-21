import fs from "fs";
import path from "path";
import { CURVE_LPS } from "@tangent/defi-resources";
import { CurveRouteService } from "./CurveRouteService";
import { LIQUIDATION_ASSETS } from "./config";
import liquidationAddresses from "../../../../../addresses.json";

const CRITICAL_USD = Number(process.env.ROUTE_DEPTH_CRITICAL_USD ?? 20_000);
const WARN_USD = Number(process.env.ROUTE_DEPTH_WARN_USD ?? 100_000);
const SOFT_USD = Number(process.env.ROUTE_DEPTH_SOFT_USD ?? 500_000);

const CURVE_API_BASE = (process.env.CURVE_API_BASE_URL ?? "https://api.curve.finance/v1").replace(/\/$/, "");
const CURVE_API_CHAIN = process.env.CURVE_API_CHAIN ?? "ethereum";
const CURVE_API_URL = `${CURVE_API_BASE}/getPools/all/${CURVE_API_CHAIN}`;

const REPORT_PATH = path.join(__dirname, "./data", "routePoolDepthReport.json");

// Addresses that are real Curve pools (from defi-resources) or local LP deployments.
// Token wrapper addresses (sUSDe, scrvUSD, wstUSR, …) are intentionally absent.
const KNOWN_CURVE_POOL_ADDRESSES: ReadonlySet<string> = new Set([
    ...Object.values(CURVE_LPS),
    ...Object.values(liquidationAddresses.lps as Record<string, string>),
].map((a) => a.toLowerCase()));

type DepthState = "critical" | "warn" | "soft" | "ok" | "unknown_api" | "missing_local_label" | "wrapper";

// Ordered most-severe → least-severe. "wrapper" is last: a wrapper step in a route
// does not drag the route's health down below real pool issues.
const SEVERITY_ORDER: DepthState[] = ["missing_local_label", "unknown_api", "critical", "warn", "soft", "ok", "wrapper"];

interface PoolInfo {
    label: string;
    address: string | null;
    state: DepthState;
    usdDepth: number | null;
    apiName: string | null;
    routeDisplays: string[];
}

interface RouteInfo {
    display: string;
    state: DepthState;
    weakestPoolLabel: string;
    weakestDepth: number | null;
}

function classifyDepth(usd: number): DepthState {
    if (usd < CRITICAL_USD) return "critical";
    if (usd < WARN_USD) return "warn";
    if (usd < SOFT_USD) return "soft";
    return "ok";
}

function extractUsdDepth(pool: any): number | null {
    for (const field of ["usdTotal", "tvl", "totalLiquidity", "usdTvl", "totalVolume"]) {
        const v = pool[field];
        if (typeof v === "number" && isFinite(v) && v > 0) return v;
        if (typeof v === "string" && v !== "") {
            const n = parseFloat(v);
            if (isFinite(n) && n > 0) return n;
        }
    }
    return null;
}

async function fetchCurvePools(): Promise<Map<string, { name: string; usdDepth: number | null }>> {
    console.log(`Fetching Curve API: ${CURVE_API_URL}`);
    const res = await fetch(CURVE_API_URL);
    if (!res.ok) throw new Error(`Curve API HTTP ${res.status}`);
    const json = (await res.json()) as any;

    const poolList: any[] = json?.data?.poolData ?? json?.data ?? [];
    const byAddress = new Map<string, { name: string; usdDepth: number | null }>();

    for (const pool of poolList) {
        const usdDepth = extractUsdDepth(pool);
        const name: string = pool.name ?? pool.symbol ?? "";
        const addrs: string[] = [];
        if (pool.address) addrs.push((pool.address as string).toLowerCase());
        if (pool.lpTokenAddress) addrs.push((pool.lpTokenAddress as string).toLowerCase());
        for (const addr of addrs) {
            if (!byAddress.has(addr)) byAddress.set(addr, { name, usdDepth });
        }
    }
    return byAddress;
}

async function main() {
    // Require FORK_RPC unless running against a local Hardhat/localhost node
    const network = process.env.HARDHAT_NETWORK ?? process.env.npm_config_network;
    const isLocalNode = network === "hardhat" || network === "localhost";
    if (!isLocalNode && !process.env.FORK_RPC) {
        console.error("Error: FORK_RPC is not set in .env.");
        console.error("Set FORK_RPC=<mainnet-rpc-url> in .env, or run the --hh variant against a local node:");
        console.error("  npm run routing:check-route-depths-hh");
        process.exit(1);
    }

    const svc = new CurveRouteService();
    await svc.loadDynamicAssets(liquidationAddresses as any);

    const csvText = await svc.getCsv();
    const rows = svc.parseCsvRows(csvText);
    console.log(`Loaded ${rows.length} CSV rows`);

    // Liquidation-direction routes only (not reverse)
    const routes = rows.map((row) => svc._formatRoutesFromCSV(row));

    // Collect pool labels and map to resolved addresses
    const poolMeta = new Map<string, { address: string | null; routeDisplays: string[] }>();
    for (const route of routes) {
        for (const step of route.singleSwaps) {
            const label = step.pool as string;
            if (!poolMeta.has(label)) {
                const resolved = LIQUIDATION_ASSETS[label];
                poolMeta.set(label, { address: resolved ? resolved.toLowerCase() : null, routeDisplays: [] });
            }
            poolMeta.get(label)!.routeDisplays.push(route.display);
        }
    }

    // Fetch Curve API pool metadata
    let curveByAddress: Map<string, { name: string; usdDepth: number | null }>;
    try {
        curveByAddress = await fetchCurvePools();
        console.log(`Curve API: ${curveByAddress.size} pool address entries`);
    } catch (e: any) {
        console.error(`Failed to fetch Curve API: ${e.message}`);
        process.exit(1);
    }

    // Classify each pool
    const poolInfos: PoolInfo[] = [];
    for (const [label, { address, routeDisplays }] of poolMeta.entries()) {
        if (address === null) {
            poolInfos.push({ label, address: null, state: "missing_local_label", usdDepth: null, apiName: null, routeDisplays });
            continue;
        }
        const apiEntry = curveByAddress.get(address);
        if (apiEntry && apiEntry.usdDepth !== null) {
            // Address matched Curve API with a usable depth figure → classify by depth
            poolInfos.push({ label, address, state: classifyDepth(apiEntry.usdDepth), usdDepth: apiEntry.usdDepth, apiName: apiEntry.name, routeDisplays });
            continue;
        }
        if (KNOWN_CURVE_POOL_ADDRESSES.has(address)) {
            // Address is a known Curve pool (from defi-resources or local deployment)
            // but the API didn't return it or returned no depth → report as unknown_api
            poolInfos.push({ label, address, state: "unknown_api", usdDepth: null, apiName: apiEntry?.name ?? null, routeDisplays });
            continue;
        }
        // Address not in CURVE_LPS or local LPs: it is a token wrapper (ERC4626, receipt token, …)
        // used by the Curve router as a deposit/withdraw step, not a liquidity pool.
        poolInfos.push({ label, address, state: "wrapper", usdDepth: null, apiName: null, routeDisplays });
    }

    const poolByLabel = new Map<string, PoolInfo>(poolInfos.map((p) => [p.label, p]));

    // Classify each route by its weakest pool
    const routeInfos: RouteInfo[] = routes.map((route) => {
        const pools = route.singleSwaps.map((step) => poolByLabel.get(step.pool as string)!);
        const worst = pools.reduce((a, b) =>
            SEVERITY_ORDER.indexOf(a.state) <= SEVERITY_ORDER.indexOf(b.state) ? a : b
        );
        return { display: route.display, state: worst.state, weakestPoolLabel: worst.label, weakestDepth: worst.usdDepth };
    });

    // Aggregate counts
    const poolCounts = Object.fromEntries(SEVERITY_ORDER.map((s) => [s, 0])) as Record<DepthState, number>;
    const routeCounts = Object.fromEntries(SEVERITY_ORDER.map((s) => [s, 0])) as Record<DepthState, number>;
    for (const p of poolInfos) poolCounts[p.state]++;
    for (const r of routeInfos) routeCounts[r.state]++;

    // Sort helpers: severity first, then shallowest depth first
    const bySeverityThenDepth = (a: { state: DepthState; usdDepth: number | null }, b: { state: DepthState; usdDepth: number | null }) => {
        const sd = SEVERITY_ORDER.indexOf(a.state) - SEVERITY_ORDER.indexOf(b.state);
        if (sd !== 0) return sd;
        return (a.usdDepth ?? -1) - (b.usdDepth ?? -1);
    };

    const sortedPools = [...poolInfos].sort(bySeverityThenDepth);
    const sortedRoutes = [...routeInfos].sort((a, b) =>
        bySeverityThenDepth({ state: a.state, usdDepth: a.weakestDepth }, { state: b.state, usdDepth: b.weakestDepth })
    );

    // --- Print report ---
    const sep = "=".repeat(115);
    const dash = "-".repeat(115);
    console.log(`\n${sep}`);
    console.log("CURVE ROUTE POOL DEPTH REPORT");
    console.log(sep);
    console.log(`CSV source:   ${process.env.ROUTE_CSV_PATH ? `local:${process.env.ROUTE_CSV_PATH}` : "remote_google_sheets"}`);
    console.log(`Thresholds:   critical < $${CRITICAL_USD.toLocaleString()} | warn < $${WARN_USD.toLocaleString()} | soft < $${SOFT_USD.toLocaleString()} | ok >= $${SOFT_USD.toLocaleString()}`);
    console.log(`Total routes: ${routes.length}   Unique pools: ${poolInfos.length}`);

    console.log("\n--- Pool counts by state ---");
    for (const s of SEVERITY_ORDER) console.log(`  ${s.padEnd(22)}: ${poolCounts[s]}`);

    console.log("\n--- Route counts by state ---");
    for (const s of SEVERITY_ORDER) console.log(`  ${s.padEnd(22)}: ${routeCounts[s]}`);

    console.log("\n--- Pool table ---");
    console.log("State".padEnd(22) + "Label".padEnd(28) + "Address".padEnd(16) + "Depth USD".padEnd(16) + "Routes".padEnd(8) + "API Name");
    console.log(dash);
    for (const p of sortedPools) {
        const depth = p.usdDepth !== null ? `$${Math.round(p.usdDepth).toLocaleString()}` : "-";
        const addr = p.address ? p.address.slice(0, 14) : "?";
        console.log(
            p.state.padEnd(22) +
            p.label.slice(0, 26).padEnd(28) +
            addr.padEnd(16) +
            depth.padEnd(16) +
            String(p.routeDisplays.length).padEnd(8) +
            (p.apiName ?? "-").slice(0, 40)
        );
    }

    const nonOkRoutes = sortedRoutes.filter((r) => r.state !== "ok" && r.state !== "wrapper");
    if (nonOkRoutes.length) {
        console.log(`\n--- Non-ok routes (${nonOkRoutes.length} / ${sortedRoutes.length}) ---`);
        console.log("State".padEnd(22) + "Weakest pool".padEnd(28) + "Depth USD".padEnd(16) + "Route");
        console.log(dash);
        for (const r of nonOkRoutes) {
            const depth = r.weakestDepth !== null ? `$${Math.round(r.weakestDepth).toLocaleString()}` : "-";
            console.log(r.state.padEnd(22) + r.weakestPoolLabel.slice(0, 26).padEnd(28) + depth.padEnd(16) + r.display);
        }
    } else {
        console.log("\nAll routes are ok.");
    }
    console.log(sep + "\n");

    // Write JSON report
    const report = {
        generatedAt: new Date().toISOString(),
        csvSource: process.env.ROUTE_CSV_PATH ? `local:${process.env.ROUTE_CSV_PATH}` : "remote_google_sheets",
        curveApiUrl: CURVE_API_URL,
        thresholds: { criticalUsd: CRITICAL_USD, warnUsd: WARN_USD, softUsd: SOFT_USD },
        summary: { totalRoutes: routes.length, uniquePools: poolInfos.length, poolCountByState: poolCounts, routeCountByState: routeCounts },
        pools: sortedPools,
        routes: sortedRoutes,
    };
    fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
    console.log(`JSON report: ${REPORT_PATH}`);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});

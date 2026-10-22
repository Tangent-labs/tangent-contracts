export const CRITICAL_USD = Number(process.env.ROUTE_DEPTH_CRITICAL_USD ?? 20_000);
export const WARN_USD = Number(process.env.ROUTE_DEPTH_WARN_USD ?? 100_000);
export const SOFT_USD = Number(process.env.ROUTE_DEPTH_SOFT_USD ?? 500_000);

const CURVE_API_BASE = (process.env.CURVE_API_BASE_URL ?? "https://api.curve.finance/v1").replace(/\/$/, "");
const CURVE_API_CHAIN = process.env.CURVE_API_CHAIN ?? "ethereum";
export const CURVE_API_URL = `${CURVE_API_BASE}/getPools/all/${CURVE_API_CHAIN}`;

export type DepthState = "critical" | "warn" | "soft" | "ok" | "unknown_api" | "missing_local_label" | "wrapper";

// Ordered most-severe → least-severe. "wrapper" is last: a wrapper step in a route
// does not drag the route's health down below real pool issues.
export const SEVERITY_ORDER: DepthState[] = [
    "missing_local_label", "unknown_api", "critical", "warn", "soft", "ok", "wrapper",
];

export function classifyDepth(usd: number): DepthState {
    if (usd < CRITICAL_USD) return "critical";
    if (usd < WARN_USD) return "warn";
    if (usd < SOFT_USD) return "soft";
    return "ok";
}

export function extractUsdDepth(pool: any): number | null {
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

export async function fetchCurvePools(): Promise<Map<string, { name: string; usdDepth: number | null }>> {
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

# Pool Liquidity Tooling for Curve Routes

This document covers the two Hardhat scripts and the shared module used to audit and maintain the liquidity quality of Curve liquidation routes.

## Overview

Liquidation routes are stored as rows in a Google Sheet CSV. Each row encodes a sequence of Curve pool hops that the protocol uses to swap collateral into USG during a liquidation. As pool liquidity changes over time, a route that was healthy at creation can degrade. These tools make that degradation visible and propose corrective actions.

Three files collaborate:

| File | Role |
|------|------|
| `poolLiquidity.ts` | Shared module: thresholds, classification logic, Curve API fetch |
| `checkRoutePoolDepths.ts` | Audit script: reads the live CSV and reports pool depth per route |
| `proposeSheetRoutes.ts` | Proposal script: finds new routes for uncovered markets and replacement routes for degraded ones |

All three live in `js-scripts/hardhat/USG/routing/Curve/`.

---

## Shared module: `poolLiquidity.ts`

### DepthState

Every pool and every route is labelled with one of seven states. The severity order runs most-severe to least-severe:

| State | Meaning | USD threshold |
|-------|---------|---------------|
| `missing_local_label` | Pool label exists in the CSV but has no address in `LIQUIDATION_ASSETS` | — |
| `unknown_api` | Address is a known Curve pool (in `CURVE_LPS` or local `lps`) but the Curve API returned no depth figure | — |
| `critical` | Pool depth below `CRITICAL_USD` | < 20 000 (default) |
| `warn` | Pool depth below `WARN_USD` | < 100 000 (default) |
| `soft` | Pool depth below `SOFT_USD` | < 500 000 (default) |
| `ok` | Pool depth at or above `SOFT_USD` | >= 500 000 (default) |
| `wrapper` | Address is not a Curve pool — it is a token wrapper (ERC4626, receipt token, etc.) used as a deposit/withdraw step by the Curve router | — |

`wrapper` is intentionally last in severity: a wrapper step does not reduce a route's health below that of its real pool hops.

A route's state equals the state of its worst pool. When comparing two routes, the one with a less-severe worst pool is preferred.

### Exports

```typescript
CRITICAL_USD: number       // default 20_000, overridable via env
WARN_USD: number           // default 100_000, overridable via env
SOFT_USD: number           // default 500_000, overridable via env
SEVERITY_ORDER: DepthState[] // most-severe → least-severe

classifyDepth(usd: number): DepthState
// Returns "critical" | "warn" | "soft" | "ok" depending on the usd value.

extractUsdDepth(pool: any): number | null
// Reads usdTotal, tvl, totalLiquidity, usdTvl, or totalVolume from a raw Curve API pool object.
// Returns the first positive finite value found, or null.

fetchCurvePools(): Promise<Map<address, { name: string; usdDepth: number | null }>>
// Fetches https://api.curve.finance/v1/getPools/all/ethereum (chain configurable).
// Keys the map by lowercased pool address; both address and lpTokenAddress are indexed.
```

---

## Audit script: `checkRoutePoolDepths.ts`

### Purpose

Reads the live Google Sheet CSV and produces a JSON report and a console table showing the depth state of every Curve pool used across all liquidation routes.

### Running

```sh
npx hardhat run js-scripts/hardhat/USG/routing/Curve/checkRoutePoolDepths.ts
```

Requires `FORK_RPC` to be set (or running against a local `hardhat`/`localhost` node).

### What it does

1. Loads the route CSV via `CurveRouteService`.
2. Resolves each pool label to an address using `LIQUIDATION_ASSETS`.
3. Fetches Curve API pool metadata via `fetchCurvePools()`.
4. Classifies each pool:
   - If the address matches an API entry with a depth figure, calls `classifyDepth()`.
   - If the address is in `CURVE_LPS` or local `lps` but has no API depth, marks it `unknown_api`.
   - If the address is not in either set, marks it `wrapper`.
   - If the label has no address in `LIQUIDATION_ASSETS`, marks it `missing_local_label`.
5. Assigns each route the state of its worst pool.
6. Prints a pool table and a non-ok route table to the console.
7. Writes a full JSON report to `js-scripts/hardhat/USG/routing/Curve/data/routePoolDepthReport.json`.

### Output

The JSON report structure:

```jsonc
{
  "generatedAt": "ISO timestamp",
  "csvSource": "remote_google_sheets | local:<path>",
  "curveApiUrl": "...",
  "thresholds": { "criticalUsd": 20000, "warnUsd": 100000, "softUsd": 500000 },
  "summary": {
    "totalRoutes": 42,
    "uniquePools": 18,
    "poolCountByState": { "ok": 12, "warn": 3, ... },
    "routeCountByState": { "ok": 35, "critical": 2, ... }
  },
  "pools": [ /* PoolInfo[], sorted severity-first then shallowest-first */ ],
  "routes": [ /* RouteInfo[], sorted severity-first then shallowest-first */ ]
}
```

---

## Proposal script: `proposeSheetRoutes.ts`

### Purpose

Identifies gaps (markets with no route in the CSV) and weaknesses (markets whose route has a degraded depth state) and proposes concrete CSV rows to address them. Does not require a forked node — it only calls the Curve API and reads the CSV.

### Running

```sh
npx hardhat run js-scripts/hardhat/USG/routing/Curve/proposeSheetRoutes.ts
```

Set `CONFIRM_ROUTE_PROPOSALS=true` to also write accepted rows to `data/sheetRouteProposals.accepted.csv`.

### Data flow

```mermaid
flowchart TD
    CSV[Google Sheet CSV] --> SVC[CurveRouteService]
    ADDRESSES[addresses.json] --> SVC
    SVC --> EXISTING_ROUTES[existingMarketRoutes]
    SVC --> SUFFIXES[routeSuffixes map\nhub → known CSV rows ending in USG*]

    CURVE_API[Curve API] --> POOL_DEPTH_MAP[poolDepthMap\naddress → depth]

    MARKETS[Market configs\naddresses.json + static configs] --> MARKET_ENTRIES[marketEntries\nlabel → collatAddress]

    subgraph NEW_ROUTES[New route proposals]
        MARKET_ENTRIES --> FOR_MARKET{market in\nexistingMarketRoutes?}
        FOR_MARKET -- no --> BUILD_CANDIDATES
        FOR_MARKET -- yes --> SKIP[skip]
        BUILD_CANDIDATES[buildCandidateRows\nsplit label on / and -\ncross with routeSuffixes] --> SCORE_CANDIDATES
        SCORE_CANDIDATES[Score each candidate\nseverityRank ASC\npoolCount ASC\nlexicographic ASC] --> TOP3[Keep top 3]
        TOP3 --> VALIDATE[Validate labels\ncheck single swaps exist]
        VALIDATE --> PROPOSALS[RouteProposal[]]
    end

    subgraph CHALLENGE[Challenge mode: replacements]
        EXISTING_ROUTES --> FOR_EXISTING[for each existing\nliquidation row]
        FOR_EXISTING --> EXISTING_STATE[compute routeDepthState\nfor existing row]
        EXISTING_STATE --> BUILD_CANDIDATES2[buildCandidateRows\nfor same marketLabel]
        BUILD_CANDIDATES2 --> FIND_BETTER{candidate with\nstrictly better state?}
        FIND_BETTER -- yes --> REPLACEMENTS[RouteReplacement[]]
        FIND_BETTER -- no --> NO_CHANGE[no action]
    end

    SUFFIXES --> BUILD_CANDIDATES
    SUFFIXES --> BUILD_CANDIDATES2
    POOL_DEPTH_MAP --> SCORE_CANDIDATES
    POOL_DEPTH_MAP --> EXISTING_STATE
    POOL_DEPTH_MAP --> BUILD_CANDIDATES2

    PROPOSALS --> ARTIFACT[sheetRouteProposals.json]
    REPLACEMENTS --> ARTIFACT
    ARTIFACT --> SUMMARY[printSummary\nconsole table]
    ARTIFACT -- CONFIRM_ROUTE_PROPOSALS=true --> ACCEPTED_CSV[sheetRouteProposals.accepted.csv]
```

### Candidate generation

For a given market label (e.g. `sUSDe/USDC`), the script:

1. Splits the label on `/` and `-` to extract hub tokens (`sUSDe`, `USDC`).
2. For each hub, looks up all CSV rows that start with that hub token and end with `USG*` (from `routeSuffixes`).
3. Prepends the market label and its collateral token to form a complete candidate row.
4. Scores each candidate by `(severityRank ASC, poolCount ASC, lexicographic ASC)` and keeps the top 3.

Default hub suffixes are seeded unconditionally: `USDC`, `frxUSD`, and `fxUSD` are available as hubs even if no row in the current CSV uses them directly.

### Challenge mode (replacement)

For every existing liquidation row in the CSV, the script runs the same candidate search. If the best candidate has a strictly less-severe `DepthState` than the current route, a `RouteReplacement` entry is emitted. The replacement table shows `current` and `proposal` rows side by side with their state and minimum pool depth.

A candidate is considered strictly better only if `SEVERITY_ORDER.indexOf(candidate.state) > SEVERITY_ORDER.indexOf(existing.state)` (higher index = less severe = better).

### Output artifact: `sheetRouteProposals.json`

```jsonc
{
  "proposedRoutes": ["label,token,pool,...,USG*"],     // deduplicated CSV rows for new markets
  "assets": { "label": "0xAddress" },                  // labels needing defi-resources entries
  "choices": ["label"],                                 // labels not yet in the CSV (need sheet rows)
  "uncoveredMarkets": [{ "label": "...", "address": "0x..." }],  // markets with no candidate found
  "proposedRouteDetails": [
    { "routeString": "...", "liquidityState": "ok", "minPoolDepthUsd": 1200000, "poolCount": 2 }
  ],
  "replacements": [
    {
      "marketLabel": "...",
      "existingRoute": "...", "existingLiquidityState": "warn", "existingMinPoolDepthUsd": 75000,
      "proposedRoute": "...", "proposedLiquidityState": "ok",  "proposedMinPoolDepthUsd": 800000,
      "existingRowCells": [...], "proposedRowCells": [...]
    }
  ]
}
```

---

## Environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `ROUTE_DEPTH_CRITICAL_USD` | `20000` | USD depth below which a pool is classified `critical` |
| `ROUTE_DEPTH_WARN_USD` | `100000` | USD depth below which a pool is classified `warn` |
| `ROUTE_DEPTH_SOFT_USD` | `500000` | USD depth below which a pool is classified `soft` |
| `CURVE_API_BASE_URL` | `https://api.curve.finance/v1` | Curve API base URL |
| `CURVE_API_CHAIN` | `ethereum` | Chain segment passed to the Curve pools endpoint |
| `FORK_RPC` | — | Required by `checkRoutePoolDepths.ts` on non-local networks |
| `CONFIRM_ROUTE_PROPOSALS` | — | Set to `"true"` to write accepted rows to `.accepted.csv` |

---

## Typical workflow

1. Run `checkRoutePoolDepths.ts` after any protocol change or on a regular cadence to detect liquidity degradation in active routes.
2. If the report shows `warn` or `critical` routes, run `proposeSheetRoutes.ts` to find replacement candidates.
3. Review `sheetRouteProposals.json` — inspect the `replacements` section for immediate fixes and `proposedRoutes` for markets with no coverage.
4. Merge approved rows back into the Google Sheet CSV and re-run `checkRoutePoolDepths.ts` to confirm the new report is clean.

import fs from "fs";
import path from "path";

import { COMMON_ERC20S, CURVE_LPS, thiefConfig } from "@tangent/defi-resources";

import liquidationAddresses from "../../../../../addresses.json";
import { STATIC_CONFIG_CONVEX_FXN, STATIC_CONFIG_CURVE_GAUGE } from "../../config/market";
import { STATIC_CONFIG_STAKEDAO_VAULT_V2 } from "../../config/markets/stakeDao";
import { CurveRouteService } from "./CurveRouteService";
import { LIQUIDATION_ASSETS } from "./config";
import { DepthState, SEVERITY_ORDER, classifyDepth, fetchCurvePools } from "./poolLiquidity";

type AddressBook = {
    markets?: { marketName: string; collatAddress: string; marketType?: string }[];
    lps?: Record<string, string>;
    wStables?: Record<string, string>;
    tokens?: { USG: string };
    oracles?: Record<string, unknown>;
};

type ProposalStatus = "validated" | "missing_labels" | "manual_review";

type RouteProposal = {
    marketLabel: string;
    marketCollateralAddress: string;
    rowCells: string[];
    routeString: string;
    validationStatus: ProposalStatus;
    validationNotes: string[];
    missingValidationLabels: MissingEntry[];
    missingDefiResourceEntries: MissingEntry[];
    liquidityState: DepthState;
    minPoolDepthUsd: number | null;
};

type MissingEntry = {
    label: string;
    address?: string;
    suggestedDefiResourceSection: "COMMON_ERC20S" | "CURVE_LPS" | "thiefConfig" | "unknown";
};

type RouteReplacement = {
    marketLabel: string;
    existingRoute: string;
    existingRowCells: string[];
    existingLiquidityState: DepthState;
    existingMinPoolDepthUsd: number | null;
    proposedRoute: string;
    proposedRowCells: string[];
    proposedLiquidityState: DepthState;
    proposedMinPoolDepthUsd: number | null;
};

type ProposalArtifact = {
    proposedRoutes: string[];
    assets: Record<string, string>;
    choices: string[];
    uncoveredMarkets: MissingEntry[];
    proposedRouteDetails: Array<{
        routeString: string;
        liquidityState: DepthState;
        minPoolDepthUsd: number | null;
        poolCount: number;
    }>;
    replacements: RouteReplacement[];
};

const DATA_DIR = path.join(__dirname, "data");
const PROPOSAL_PATH = path.join(DATA_DIR, "sheetRouteProposals.json");
const ACCEPTED_CSV_PATH = path.join(DATA_DIR, "sheetRouteProposals.accepted.csv");

const addresses = liquidationAddresses as unknown as AddressBook;

// Addresses that are real Curve pools; token wrappers (sUSDe, wstUSR, …) are absent.
const KNOWN_CURVE_POOL_ADDRESSES: ReadonlySet<string> = new Set([
    ...Object.values(CURVE_LPS as Record<string, string>),
    ...Object.values((liquidationAddresses as any).lps as Record<string, string> ?? {}),
].map((a) => a.toLowerCase()));

function mostSevere(a: DepthState, b: DepthState): DepthState {
    return SEVERITY_ORDER.indexOf(a) <= SEVERITY_ORDER.indexOf(b) ? a : b;
}

function extractPoolLabels(rowCells: string[]): string[] {
    return rowCells.filter((_, i) => i > 0 && i % 2 === 1);
}

function routeDepthState(
    rowCells: string[],
    poolDepthMap: Map<string, { name: string; usdDepth: number | null }>
): { state: DepthState; minDepthUsd: number | null } {
    const labels = extractPoolLabels(rowCells);
    let worstState: DepthState = "ok";
    let minDepthUsd: number | null = null;

    for (const label of labels) {
        if (label.endsWith("*")) continue;
        const address = (LIQUIDATION_ASSETS as Record<string, string>)[label]?.toLowerCase();
        if (!address) { worstState = mostSevere(worstState, "missing_local_label"); continue; }
        if (!KNOWN_CURVE_POOL_ADDRESSES.has(address)) { worstState = mostSevere(worstState, "wrapper"); continue; }
        const entry = poolDepthMap.get(address);
        if (!entry || entry.usdDepth === null) { worstState = mostSevere(worstState, "unknown_api"); continue; }
        const s = classifyDepth(entry.usdDepth);
        worstState = mostSevere(worstState, s);
        if (minDepthUsd === null || entry.usdDepth < minDepthUsd) minDepthUsd = entry.usdDepth;
    }
    return { state: worstState, minDepthUsd };
}

async function main() {
    const svc = new CurveRouteService();
    await svc.loadDynamicAssets(addresses as Required<Pick<AddressBook, "lps" | "wStables" | "tokens">>);

    const csvText = await svc.getCsv();
    const csvRows = svc.parseCsvRows(csvText);
    const csvLabels = new Set(csvRows.flat());
    const sourceRoutes = csvRows.map((row) => svc._formatRoutesFromCSV([...row] as any));
    const routeSuffixes = buildRouteSuffixes(csvRows);
    const existingMarketRoutes = new Set(csvRows.filter((row) => row[row.length - 1] === "USG*").map((row) => row[0]));
    const marketEntries = collectMarketEntries();

    let poolDepthMap: Map<string, { name: string; usdDepth: number | null }>;
    try {
        poolDepthMap = await fetchCurvePools();
        console.log(`Curve API: ${poolDepthMap.size} pools loaded`);
    } catch (e: any) {
        console.warn(`Warning: could not fetch Curve pool depths (${e.message}). Sorting by route length only.`);
        poolDepthMap = new Map();
    }

    const proposals: RouteProposal[] = [];
    const uncoveredMarketsWithoutProposal: MissingEntry[] = [];

    for (const market of marketEntries) {
        if (existingMarketRoutes.has(market.label)) {
            continue;
        }

        const candidates = buildCandidateRows(market.label, routeSuffixes, poolDepthMap);
        if (!candidates.length) {
            uncoveredMarketsWithoutProposal.push({
                label: market.label,
                address: market.address,
                suggestedDefiResourceSection: "CURVE_LPS",
            });
            continue;
        }

        for (const { rowCells, liquidityState, minPoolDepthUsd } of candidates) {
            const route = svc._formatRoutesFromCSV([...rowCells] as any);
            const labelValidation = svc.validateRouteRows([rowCells]);
            const missingValidationLabels = Array.from(labelValidation.missing).map((label) => missingEntryForLabel(label, marketEntries));
            const missingDefiResourceEntries = findMissingDefiResourceEntries(rowCells, marketEntries);
            const existingSingleSwaps = route.singleSwaps.every((singleSwap) =>
                sourceRoutes.some((sourceRoute) =>
                    sourceRoute.singleSwaps.some(
                        (sourceSingleSwap) =>
                            sourceSingleSwap.in === singleSwap.in &&
                            sourceSingleSwap.pool === singleSwap.pool &&
                            sourceSingleSwap.out === singleSwap.out
                    )
                )
            );
            const validationNotes: string[] = [];
            let validationStatus: ProposalStatus = "validated";

            if (!labelValidation.valid) {
                validationStatus = "missing_labels";
                validationNotes.push("One or more row labels are missing from local LIQUIDATION_ASSETS after dynamic asset loading.");
            }
            if (!existingSingleSwaps) {
                validationStatus = validationStatus === "validated" ? "manual_review" : validationStatus;
                validationNotes.push("At least one single swap is not present in current sheet-generated route references; run routing:generate-routes after sheet/package updates.");
            }

            proposals.push({
                marketLabel: market.label,
                marketCollateralAddress: market.address,
                rowCells,
                routeString: route.display,
                validationStatus,
                validationNotes,
                missingValidationLabels,
                missingDefiResourceEntries,
                liquidityState,
                minPoolDepthUsd,
            });
        }
    }

    // Challenge mode: for every existing route, propose a replacement if a better-liquidity candidate exists
    const existingLiquidationRows = csvRows.filter((row) => row[row.length - 1] === "USG*");
    const replacements: RouteReplacement[] = [];
    for (const existingRow of existingLiquidationRows) {
        const { state: existingState, minDepthUsd: existingMinDepth } = routeDepthState(existingRow, poolDepthMap);
        const marketLabel = existingRow[0];
        const existingRoute = svc._formatRoutesFromCSV([...existingRow] as any);
        const candidates = buildCandidateRows(marketLabel, routeSuffixes, poolDepthMap);
        const bestCandidate = candidates.find(
            (c) => SEVERITY_ORDER.indexOf(c.liquidityState) > SEVERITY_ORDER.indexOf(existingState)
        );
        if (!bestCandidate) continue;
        replacements.push({
            marketLabel,
            existingRoute: existingRoute.display,
            existingRowCells: existingRow,
            existingLiquidityState: existingState,
            existingMinPoolDepthUsd: existingMinDepth,
            proposedRoute: svc._formatRoutesFromCSV([...bestCandidate.rowCells] as any).display,
            proposedRowCells: bestCandidate.rowCells,
            proposedLiquidityState: bestCandidate.liquidityState,
            proposedMinPoolDepthUsd: bestCandidate.minPoolDepthUsd,
        });
    }

    const missingDefiResourceEntries = uniqueMissingEntries(proposals.flatMap((proposal) => proposal.missingDefiResourceEntries));

    const detailsByRoute = new Map<string, { routeString: string; liquidityState: DepthState; minPoolDepthUsd: number | null; poolCount: number }>();
    for (const p of proposals) {
        if (!detailsByRoute.has(p.routeString)) {
            detailsByRoute.set(p.routeString, {
                routeString: p.routeString,
                liquidityState: p.liquidityState,
                minPoolDepthUsd: p.minPoolDepthUsd,
                poolCount: (p.rowCells.length - 1) / 2,
            });
        }
    }
    const proposedRouteDetails = Array.from(detailsByRoute.values()).sort((a, b) => a.routeString.localeCompare(b.routeString));

    const artifact: ProposalArtifact = {
        proposedRoutes: uniqueStrings(proposals.map((proposal) => proposal.routeString)),
        assets: Object.fromEntries(
            missingDefiResourceEntries
                .filter((entry) => entry.address)
                .map((entry) => [entry.label, entry.address!])
        ),
        choices: buildMissingSheetChoices(proposals, csvLabels),
        uncoveredMarkets: uncoveredMarketsWithoutProposal,
        proposedRouteDetails,
        replacements,
    };

    fs.writeFileSync(PROPOSAL_PATH, JSON.stringify(artifact, null, 2));

    if (process.env.CONFIRM_ROUTE_PROPOSALS === "true") {
        fs.writeFileSync(ACCEPTED_CSV_PATH, artifact.proposedRoutes.join("\n"));
    }

    printSummary(artifact);
}

function collectMarketEntries() {
    const entries = new Map<string, string>();

    for (const market of addresses.markets || []) {
        entries.set(market.marketName, market.collatAddress);
    }
    for (const config of Object.values(STATIC_CONFIG_CONVEX_FXN)) {
        entries.set(config.collatName, config.collatToken);
    }
    for (const config of Object.values(STATIC_CONFIG_CURVE_GAUGE)) {
        entries.set(config.collatName, config.collatToken);
    }
    for (const config of Object.values(STATIC_CONFIG_STAKEDAO_VAULT_V2)) {
        entries.set(config.collatName, config.collatToken);
    }

    return Array.from(entries.entries())
        .map(([label, address]) => ({ label, address }))
        .sort((a, b) => a.label.localeCompare(b.label));
}

function buildRouteSuffixes(rows: string[][]) {
    const suffixes = new Map<string, string[][]>();
    const defaults = [
        ["USDC", "USG-USDC*", "USG*"],
        ["frxUSD", "USG-frxUSD*", "USG*"],
        ["fxUSD", "USDC/fxUSD*", "USDC", "USG-USDC*", "USG*"],
    ];

    for (const row of [...rows, ...defaults]) {
        if (row.length >= 3 && row.length % 2 === 1 && row[row.length - 1] === "USG*") {
            const current = suffixes.get(row[0]) || [];
            current.push(row);
            suffixes.set(row[0], current);
        }
    }

    return suffixes;
}

function buildCandidateRows(
    marketLabel: string,
    routeSuffixes: Map<string, string[][]>,
    poolDepthMap: Map<string, { name: string; usdDepth: number | null }>
): Array<{ rowCells: string[]; liquidityState: DepthState; minPoolDepthUsd: number | null }> {
    const hubs = uniqueStrings(marketLabel.split(/[/-]/).map((label) => label.trim()).filter(Boolean));
    const rows: string[][] = [];

    for (const hub of hubs) {
        for (const suffix of routeSuffixes.get(hub) || []) {
            rows.push([marketLabel, marketLabel, hub, ...suffix.slice(1)]);
        }
    }

    return dedupeRows(rows)
        .map((rowCells) => {
            const { state, minDepthUsd } = routeDepthState(rowCells, poolDepthMap);
            return { rowCells, liquidityState: state, minPoolDepthUsd: minDepthUsd };
        })
        .sort((a, b) => {
            const sd = SEVERITY_ORDER.indexOf(a.liquidityState) - SEVERITY_ORDER.indexOf(b.liquidityState);
            if (sd !== 0) return sd;
            const ld = a.rowCells.length - b.rowCells.length;
            if (ld !== 0) return ld;
            return a.rowCells.join(",").localeCompare(b.rowCells.join(","));
        })
        .slice(0, 3);
}

function findMissingDefiResourceEntries(rowCells: string[], marketEntries: { label: string; address: string }[]) {
    return uniqueMissingEntries(
        rowCells
            .filter((label) => !label.endsWith("*") && !hasDefiResourceLabel(label))
            .map((label) => missingEntryForLabel(label, marketEntries))
            .filter((entry) => entry.address)
    );
}

function buildMissingSheetChoices(proposals: RouteProposal[], csvLabels: Set<string>) {
    return uniqueStrings(
        proposals
            .flatMap((proposal) => proposal.rowCells)
            .filter((label) => label !== "" && !csvLabels.has(label))
    );
}

function missingEntryForLabel(label: string, marketEntries: { label: string; address: string }[]): MissingEntry {
    const market = marketEntries.find((entry) => entry.label === label);
    const dynamicLpAddress = label.endsWith("*") ? addresses.lps?.[label.slice(0, -1)] : undefined;
    const dynamicStableAddress = label.endsWith("*") ? addresses.wStables?.[label.slice(0, -1)] : undefined;
    const address = market?.address || dynamicLpAddress || dynamicStableAddress || getKnownAddress(label);

    return {
        label,
        address,
        suggestedDefiResourceSection: label.includes("/") || label.includes("-") || label.endsWith("*") ? "CURVE_LPS" : "COMMON_ERC20S",
    };
}

function hasDefiResourceLabel(label: string) {
    const address = getKnownAddress(label)?.toLowerCase();
    const commonErc20Addresses = Object.values(COMMON_ERC20S as Record<string, string>).map((value) => value.toLowerCase());
    const curveLpAddresses = Object.values(CURVE_LPS as Record<string, string>).map((value) => value.toLowerCase());

    return Boolean(
        (COMMON_ERC20S as Record<string, string>)[label] ||
        (CURVE_LPS as Record<string, string>)[label] ||
        (address && (commonErc20Addresses.includes(address) || curveLpAddresses.includes(address))) ||
        Object.prototype.hasOwnProperty.call((thiefConfig as any).THIEF_TOKEN_CONFIG || {}, label)
    );
}

function getKnownAddress(label: string) {
    return (
        (LIQUIDATION_ASSETS as Record<string, string>)[label] ||
        (COMMON_ERC20S as Record<string, string>)[label] ||
        (CURVE_LPS as Record<string, string>)[label]
    );
}

function dedupeRows(rows: string[][]) {
    const seen = new Set<string>();
    return rows.filter((row) => {
        const key = row.join("\u0000");
        if (seen.has(key)) {
            return false;
        }
        seen.add(key);
        return true;
    });
}

function uniqueStrings(values: string[]) {
    return Array.from(new Set(values)).sort();
}

function uniqueMissingEntries(entries: MissingEntry[]) {
    const seen = new Map<string, MissingEntry>();
    for (const entry of entries) {
        seen.set(entry.label, entry);
    }
    return Array.from(seen.values()).sort((a, b) => a.label.localeCompare(b.label));
}

function printSummary(artifact: ProposalArtifact) {
    console.log(`Wrote ${PROPOSAL_PATH}`);
    console.table([{
        proposedRoutes: artifact.proposedRoutes.length,
        replacements: artifact.replacements.length,
        assets: Object.keys(artifact.assets).length,
        choices: artifact.choices.length,
        uncoveredMarkets: artifact.uncoveredMarkets.length,
    }]);
    if (artifact.proposedRoutes.length) {
        console.log("\nProposed routes:\n");
        artifact.proposedRoutes.forEach((route) => console.log(route));
    } else {
        console.log("\nNo proposed routes.");
    }
    if (Object.keys(artifact.assets).length) {
        console.log("\nAssets:");
        Object.entries(artifact.assets).forEach(([label, address]) => console.log(`${label}: ${address}`));
    }
    if (artifact.choices.length) {
        console.log("\nChoices:");
        artifact.choices.forEach((label) => console.log(label));
    }
    if (artifact.replacements.length) {
        console.log("\nReplacement proposals (better liquidity available):");
        console.table(artifact.replacements.flatMap((r) => [
            { market: r.marketLabel, version: "current",  state: r.existingLiquidityState,  minUsd: r.existingMinPoolDepthUsd?.toFixed(0) ?? "?", route: r.existingRoute },
            { market: "",            version: "proposal", state: r.proposedLiquidityState,  minUsd: r.proposedMinPoolDepthUsd?.toFixed(0) ?? "?", route: r.proposedRoute },
        ]));
    }
    if (artifact.uncoveredMarkets.length) {
        console.log("\nWarning: markets with no route and no proposal (no known hub suffix):");
        artifact.uncoveredMarkets.forEach(({ label, address }) => console.log(`  ${label}${address ? ` (${address})` : ""}`));
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

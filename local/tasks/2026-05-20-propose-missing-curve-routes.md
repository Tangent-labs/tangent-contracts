# Task Plan

## Goal

Create a helper script that makes Google Sheet route entry easier by proposing copy-pasteable route rows for newly added market LPs and reporting any missing `@tangent/defi-resources` address/config entries needed to make those sheet values valid.

## Observed context

- The canonical route source is the Google Sheet loaded by `CurveRouteService.getCsv()`, not `finalRoutes.json`.
- `finalRoutes.json`, `rawRoutes.json`, and `singleSwaps.json` are generated artifacts from the sheet-driven flow.
- The sheet uses alternating columns:
  - `IN`
  - `POOL1`
  - `OUT1`
  - `POOL2`
  - `OUT2`
  - ...
- The screenshot shows Google Sheets data validation dropdowns. Valid choices must include both:
  - token labels such as `USDC`, `frxUSD`, `sUSDS`, `BOLD`
  - pool labels such as `BOLD/USDC`, `eUSD/USDC`, `USG-USDC*`
- `CurveRouteService.validateCsv()` validates sheet labels against `LIQUIDATION_ASSETS`.
- `LIQUIDATION_ASSETS` is built from `COMMON_ERC20S`, `CURVE_LPS`, hardcoded local addresses, and dynamic `addresses.json` entries via `loadDynamicAssets()`.
- Newly added markets live in market config and/or `addresses.json`, but some labels may still be missing from the external `@tangent/defi-resources` package.
- Because `@tangent/defi-resources` is a separate package, this repository should not automatically modify it. The helper should instead print copy-pasteable missing entries.
- Existing generated final routes can still be used as a reference library of known route suffixes/prefixes, but they are not the place where new human-readable routes should be added.

## Assumptions

- The user will manually paste accepted rows into the Google Sheet.
- The script should not write to Google Sheets directly.
- The script should not modify the separate `@tangent/defi-resources` package.
- The script should not mutate generated route files by default.
- "Missing routes" means market LP labels that should have sheet rows toward `USG*` but do not currently have obvious valid rows in the sheet-generated outputs.
- The preferred output is easy for Google Sheets:
  - one table/CSV block containing route rows split into cells
  - one list of validation dropdown labels to add
  - one list of missing address constants/config snippets for `defi-resources`

## Proposed implementation

1. Add a route proposal helper script.
   - Suggested file: `js-scripts/hardhat/USG/routing/Curve/proposeSheetRoutes.ts`.
   - Load the current Google Sheet CSV using the existing `CurveRouteService.getCsv()` path.
   - Optionally allow `ROUTE_CSV_PATH=...` for testing against a downloaded CSV.
   - Load `addresses.json` and call `svc.loadDynamicAssets(addresses)` so local dynamic labels such as `USG*`, `USG-USDC*`, and `USG-frxUSD*` are available.

2. Build the sheet label universe.
   - Start from `LIQUIDATION_ASSETS`.
   - Add dynamic labels from `addresses.json`.
   - Add market labels from:
     - `addresses.markets[*].marketName`
     - `STATIC_CONFIG_CONVEX_FXN`
     - `STATIC_CONFIG_CURVE_GAUGE`
     - `STATIC_CONFIG_STAKEDAO_VAULT_V2`
   - Build both `label -> address` and `address -> preferred label`.

3. Detect labels missing from local validation sources.
   - For each market label and candidate pool/coin used in proposed rows, check whether it exists in `LIQUIDATION_ASSETS` after dynamic loading.
   - If a label is missing locally, classify it as:
     - missing token address constant, likely `COMMON_ERC20S`
     - missing Curve LP address constant, likely `CURVE_LPS`
     - missing thief config entry, if route validation/funding needs it
   - Output copy-pasteable snippets or at minimum `{ label, address, suggestedDefiResourceSection }`.

4. Fetch Curve API pool metadata for route discovery.
   - Use a configurable Curve API endpoint, defaulting to the public Curve API documentation host.
   - Parse pool metadata into:
     - pool label candidates
     - pool address / LP token address
     - coin addresses and symbols
   - Supplement with onchain `_getPoolInfo()` for labels already present in `LIQUIDATION_ASSETS` or dynamic `addresses.json`, because Curve API may not know local/dynamic USG pools.

5. Generate Google Sheet row proposals.
   - For each newly added or uncovered market LP label, find candidate paths from market LP to `USG*`.
   - Prefer reusing known route suffixes already present in the sheet/generated outputs:
     - `USDC -> USG-USDC* -> USG*`
     - `frxUSD -> USG-frxUSD* -> USG*`
     - stable intermediary paths already present in existing rows
   - Emit rows as ordered cells:
     - `IN, POOL1, OUT1, POOL2, OUT2, ...`
   - Also emit a route-string form:
     - `BOLD/USDC >> BOLD/USDC >> USDC >> USG-USDC* >> USG*`
   - Mark rows as `copy_to_sheet`, not auto-applied.

6. Validate proposed rows before presenting them as good candidates.
   - Convert proposed cell rows into route strings using the same parser behavior as the generator.
   - Use existing `formatSingleSwaps()` and `testRouteSteps()` to determine whether all single swaps can produce valid Curve router params.
   - Report invalid rows separately with the failed segment.
   - Keep unsupported mechanics, such as native ETH wrappers and special LP withdraws, in `manual_review`.

7. Write a proposal artifact.
   - Suggested output: `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.json`.
   - Include:
     - market label
     - market collateral address
     - proposed row cells
     - route string
     - validation status
     - missing validation labels
     - missing `defi-resources` entries
   - Also print a compact CSV block to stdout for pasting into the Google Sheet.

8. Add explicit confirmation behavior without direct external writes.
   - Default mode: only write proposal JSON and print copy-pasteable rows/snippets.
   - Optional `CONFIRM_ROUTE_PROPOSALS=true`: write a local `sheetRouteProposals.accepted.csv` file containing only validated proposals.
   - Do not edit Google Sheets automatically.
   - Do not edit `@tangent/defi-resources`.
   - Do not edit `finalRoutes.json` directly.

9. Add script wiring.
   - Add `routing:propose-sheet-routes` to `package.json`.
   - Keep `routing:generate-routes` as the step that consumes the Google Sheet after the user has pasted accepted rows.

## Expected file changes

| File | Action | Reason |
| ---- | ------ | ------ |
| `js-scripts/hardhat/USG/routing/Curve/proposeSheetRoutes.ts` | add | New helper that proposes Google Sheet rows and missing address/config entries. |
| `js-scripts/hardhat/USG/routing/Curve/CurveRouteService.ts` | modify | Reuse/expose parsing, CSV loading, dynamic asset loading, and route validation helpers without duplicating logic. |
| `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.json` | add/generated | Review artifact containing proposed rows, validation status, and missing address/config notes. |
| `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.accepted.csv` | optional generated | Copy-pasteable accepted rows after explicit confirmation flag. |
| `package.json` | modify | Add `routing:propose-sheet-routes`. |

## Validation plan

- `npx hardhat compile`
- `npm run routing:propose-sheet-routes`
- Inspect `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.json`
- If proposals are acceptable: `CONFIRM_ROUTE_PROPOSALS=true npm run routing:propose-sheet-routes`
- Manually paste accepted rows into the Google Sheet.
- Manually add missing data-validation dropdown values in the Google Sheet.
- Update `@tangent/defi-resources` separately with any reported missing address/config entries.
- After the sheet and package are updated: `npm run routing:generate-routes`
- `npm run routing:hydrate-routes`
- `npm run routing:test-curve-routes`

## Risks / open questions

- Direct Google Sheet writes are explicitly out of scope for this plan.
- Direct edits to `@tangent/defi-resources` are explicitly out of scope; the helper only reports required snippets/labels.
- Curve API naming may not match the sheet labels, so the helper must prefer existing sheet labels and `LIQUIDATION_ASSETS` labels when possible.
- Some route mechanics may remain unsupported by the generic Curve router tester, especially native ETH wrappers, ERC4626 vault wrapping/unwrapping, and LP remove-liquidity one-coin routes.
- If a market has multiple possible paths, ranking must be deterministic and should prefer short routes through already-used stable hubs.
- If Google Sheet validation dropdowns are maintained manually, the script can only tell the user what labels to add; it cannot verify the Sheet UI validation rules unless the CSV export contains the added values.

## Persistence

Plan persisted to `./local/tasks/2026-05-20-propose-missing-curve-routes.md`.

---

## Execution notes - 2026-05-20

Execution status: partial implementation complete; planned validation is blocked by the local environment before the new script can run.

Implemented:

- Added `js-scripts/hardhat/USG/routing/Curve/proposeSheetRoutes.ts`.
- Added `routing:propose-sheet-routes` to `package.json`.
- Extended `CurveRouteService` with:
  - `ROUTE_CSV_PATH` support in `getCsv()`.
  - reusable `parseCsvRows()`.
  - reusable `validateRouteRows()`.

Validation status:

- `npx hardhat compile`: failed before compile because `hardhat-foundry` could not run `forge`; `forge` is not installed or not on `PATH`.
- `npm run routing:propose-sheet-routes`: failed for the same `hardhat-foundry` / missing `forge` prerequisite before the script executed.
- `npx tsc --noEmit --pretty false`: failed with broad pre-existing repository errors. The only new-file typing issue found in `proposeSheetRoutes.ts` was fixed, and a filtered re-run showed no remaining diagnostics for the touched route files.
- `git diff --check -- js-scripts/hardhat/USG/routing/Curve/proposeSheetRoutes.ts js-scripts/hardhat/USG/routing/Curve/CurveRouteService.ts package.json`: passed, with line-ending warnings only.

Deviations:

- `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.json` was not generated because the planned proposal command could not start without `forge`.
- `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.accepted.csv` was not generated because `CONFIRM_ROUTE_PROPOSALS=true` was not run and the base proposal command is blocked.

Remaining work:

- Install Foundry / make `forge` available on `PATH`, then re-run:
  - `npx hardhat compile`
  - `npm run routing:propose-sheet-routes`
- Inspect `js-scripts/hardhat/USG/routing/Curve/data/sheetRouteProposals.json` after generation.

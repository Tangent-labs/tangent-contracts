# Task Plan

## Goal

Upgrade the USG mainnet deployment flow so it consistently uses the already deployed Curve pools `0x97ba10115da528c113462ede9c20d7adc806d93f` for USG/USDC and `0xefc056790bb19702b2164ec6ea6ba3ae01d81195` for USG/frxUSD instead of behaving like those pools may need to be newly deployed or missing from downstream routing/address data.

## Observed context

- `js-scripts/hardhat/USG/actions/deployMainnetAddresses.ts` creates `LpDeployContext` and currently calls `lpDeployContext.fetchLPsAndSeedLps(baseContext, seedLpAmount)`.
- `js-scripts/hardhat/USG/contexts/LPDeployContext.ts` already has `fetchLPsAndSeedLps`, which binds `stableLp["USG-USDC"]` to `PROD_ADDRESSES.USG_USDC` and `stableLp["USG-frxUSD"]` to `PROD_ADDRESSES.USG_frxUSD`, then seeds both pools.
- `ignition/prod_addresses.ts` already contains the exact pool addresses from the request:
  - `USG_USDC: "0x97ba10115da528c113462ede9c20d7adc806d93f"`
  - `USG_frxUSD: "0xefc056790bb19702b2164ec6ea6ba3ae01d81195"`
- `js-scripts/hardhat/USG/contexts/BaseContext.ts` serializes `lpDeployContext.stableLp` into `addresses.json` via `createJSONAddress`, so any correctly populated `stableLp` entries become `addresses.lps["USG-USDC"]` and `addresses.lps["USG-frxUSD"]`.
- Curve route generation and hydration load dynamic LP assets from `addresses.json` using the `USG-USDC*` and `USG-frxUSD*` names.
- `deployMainnetAddresses.ts` approves only `USG-USDC` directly, while routes and setup scripts reference both `USG-USDC` and `USG-frxUSD`.
- `deployUSG.ts` is the local deploy-new flow and should remain separate from the mainnet-address flow.

## Assumptions

- "deploymainet function" refers to `deployMainnetAddresses` in `js-scripts/hardhat/USG/actions/deployMainnetAddresses.ts`.
- "FRXUSD" refers to `frxUSD`, matching existing code keys `USG-frxUSD` and `PROD_ADDRESSES.USG_frxUSD`.
- The requested change is about using existing mainnet pools in the deployment/setup context, not deploying new Curve pools.
- The mainnet/fork flow must seed the existing pools, and the amount passed to `deployMainnetAddresses` must be added as liquidity to each configured USG pool.

## Proposed implementation

1. Make the mainnet pool mapping explicit and centralized in `LPDeployContext`.
   - Keep the existing semantic keys `USG-USDC` and `USG-frxUSD`.
   - Ensure these keys map to `PROD_ADDRESSES.USG_USDC` and `PROD_ADDRESSES.USG_frxUSD`.
   - Prefer a small helper such as `fetchMainnetStableLps()` or a typed constant to reduce the chance that one pool is omitted later.

2. Update or keep `fetchLPsAndSeedLps` so it explicitly fetches existing pools before seeding them.
   - First attach both already deployed pools to `stableLp`.
   - Then add liquidity to both pools using the amount passed from `deployMainnetAddresses`; keep the existing default when no amount is passed.
   - This makes `deployMainnetAddresses` clearly account for existing pools while preserving the required seeding behavior.

3. Update `deployMainnetAddresses` to use the explicit existing-pool helper.
   - Replace the implicit "fetch and seed" call if a clearer two-step API is introduced.
   - Ensure both `USG-USDC` and `USG-frxUSD` are present before deploying oracles/markets and before generating `addresses.json`.

4. Approve both USG pool LPs for test users in the mainnet flow.
   - Keep existing approval for `USG-USDC`.
   - Add the corresponding approval for `USG-frxUSD`, because downstream generated actions, liquidations, and routes use both pools.

5. Optionally make routing config robust without relying only on generated `addresses.json`.
   - If route generation must work before `addresses.json` exists, add static `LIQUIDATION_ASSETS["USG-USDC*"]` and `LIQUIDATION_ASSETS["USG-frxUSD*"]` entries from `PROD_ADDRESSES`.
   - If route generation is always run after `addresses.json`, leave routing config unchanged and rely on `loadDynamicAssets`.

## Expected file changes

| File | Action | Reason |
| ---- | ------ | ------ |
| `js-scripts/hardhat/USG/contexts/LPDeployContext.ts` | modify | Explicitly attach both already deployed mainnet USG pools and optionally separate pool fetching from seeding. |
| `js-scripts/hardhat/USG/actions/deployMainnetAddresses.ts` | modify | Use the explicit existing-pool path and approve both USG pool contracts for test users. |
| `js-scripts/hardhat/USG/routing/Curve/config.ts` | optional modify | Add static USG pool dynamic-asset aliases only if route generation must work without first generating `addresses.json`. |

## Validation plan

- `npx hardhat compile`
- `npm run deploy:usg-local`
- Inspect `addresses.json` and confirm:
  - `lps["USG-USDC"] === "0x97ba10115da528c113462ede9c20d7adc806d93f"`
  - `lps["USG-frxUSD"] === "0xefc056790bb19702b2164ec6ea6ba3ae01d81195"`
- `npm run routing:hydrate-routes`
- `npm run routing:test-curve-routes`
- Optional fork sanity check: `npx hardhat run js-scripts/hardhat/USG/actions/check-USG-balances.ts --network localhost`

## Risks / open questions

- The current mainnet-address flow seeds existing pools. This is expected: the passed amount should be added as liquidity to the existing `USG-USDC` and `USG-frxUSD` pools.
- `PROD_ADDRESSES.USG_frxUSD` uses lowercase `frxUSD` naming while the request says `FRXUSD`; implementation should keep the existing code key to avoid breaking route names and JSON consumers.
- `createJSONAddress` always adds `lps["TAN-WETH"]` from `lpDeployContext.tanLP`, which may be undefined in the mainnet-address flow. This is adjacent to the USG pool request but may affect generated `addresses.json`; only fix it if it blocks validation.
- If the external `@tangent/defi-resources` package later includes these USG pools, duplicating them in routing config could create two sources of truth. Prefer `PROD_ADDRESSES` for this repository-specific deployment state.

## Persistence

Plan persisted to `./local/tasks/2026-05-20-upgrade-deploy-mainnet-existing-usg-pools.md`.

## Execution notes - 2026-05-20

### Execution status

- Implemented.
- `LPDeployContext` now centralizes the two already deployed mainnet USG Curve pool addresses in `MAINNET_USG_STABLE_LPS`.
- Added `fetchMainnetStableLps()` to attach `USG-USDC` and `USG-frxUSD` from `PROD_ADDRESSES` before seeding.
- Kept `fetchLPsAndSeedLps()` as the mainnet flow entry point, now using the explicit fetch helper before seeding both pools.
- Updated `deployMainnetAddresses` to approve both `USG-USDC` and `USG-frxUSD` LP contracts for test users.

### Validation status

- `npx hardhat compile`: failed before compilation because `hardhat-foundry` could not find `forge` in PATH.
- `npm run deploy:usg-local`: failed for the same `forge` PATH prerequisite before executing the deploy script.
- `npm run routing:hydrate-routes`: failed for the same `forge` PATH prerequisite before executing the route hydration script.
- `npm run routing:test-curve-routes`: failed for the same `forge` PATH prerequisite before executing the route test script.
- Address inspection was not run because `npm run deploy:usg-local` did not execute.
- Optional fork sanity check was not run because the required Hardhat validation commands did not execute.

### Deviations

- Did not modify `js-scripts/hardhat/USG/routing/Curve/config.ts`; route generation already loads `USG-USDC*` and `USG-frxUSD*` dynamically from `addresses.json`, so the optional static aliases were not needed.

### Remaining work

- Install Foundry or put `forge` on PATH, then rerun the validation plan.

# Tangent Contracts

Smart contracts powering **Tangent Protocol**, a collateralized debt platform built around **USG**, an overcollateralized stablecoin backed by Curve/Convex LP tokens and other yield-bearing collateral.

## Overview

- **USG** — the protocol's stablecoin, minted against deposited collateral.
- **sUSG** — an ERC-4626 savings vault (built on Yearn V3) that lets users stake USG for yield.
- **TAN / vsTAN** — the protocol's governance token and its vote-escrowed form, used to distribute protocol rewards.
- **Markets** (`ConvexCrvLPMarket`, `ConvexFxnLPMarket`, `BasicERC20Market`) — collateral/debt markets that let users deposit collateral, borrow USG, and get liquidated when under-collateralized.
- **Oracles** — price feeds for LP and stable-swap collateral (see [`documentation/CurveOracle.md`](documentation/CurveOracle.md) for the manipulation-resistance rationale).
- **ZappingProxy** — lets users deposit/repay with any ERC20 by swapping into the market's collateral via Enso Finance (see [`documentation/features/ZapDeposit.md`](documentation/features/ZapDeposit.md) / [`ZapRepay.md`](documentation/features/ZapRepay.md)).
- **Liquidations** — permissionless liquidation of unhealthy positions (see [`documentation/features/Liquidations.md`](documentation/features/Liquidations.md)).

More architecture notes live under [`documentation/`](documentation), including market class inheritance ([`documentation/archi/MarketClass.md`](documentation/archi/MarketClass.md)) and routing ([`documentation/archi/routing.md`](documentation/archi/routing.md)).

## Architecture Overview

```
                             ┌─────────────────────────┐
                             │       ControlTower      │  Access control & roles
                             └────────────┬────────────┘
                                          │
          ┌───────────────────────────────┼──────────────────────────────┐
          │                               │                              │
  ┌───────▼──────┐              ┌─────────▼────────┐            ┌───────▼─────────┐
  │ MarketCreator│              │   IRCalculator   │            │RewardAccumulator│
  │  (Factory)   │              │  (Rate Engine)   │            │ (Yield Splitter)│
  └───────┬──────┘              └─────────┬────────┘            └───────┬─────────┘
          │                               │                              │
          │  deploys                      │  checkpoints                 │  distributes
          ▼                               ▼                              ▼
  ┌────────────────────────────────────────────────────────────────────────────────┐
  │                               Market (per collateral)                          │
  │   BasicERC20 │ ConvexCrvLP │ ConvexFxnLP │ CurveGauge │ StakeDaoVault          │
  └───────────────────────┬─────────────────────────────┬──────────────────────────┘
          ▲               │  mints / burns               │  stakes collateral
          │               ▼                              ▼
  ┌───────┴──────┐  ┌─────────────┐             ┌──────────────────────┐
  │ ZappingProxy │  │     USG     │             │   Yield Protocols    │
  │ (Swap Router)│  │ (Stablecoin)│             │ Convex / Curve /     │
  └──────────────┘  └──────┬──────┘             │ StakeDao             │
   any token in            │  trades in         └──────────────────────┘
   collateral out          ▼
                  ┌─────────────────┐
                  │   USG/x LP Pool │  on-chain price reference
                  │  (e.g. Curve)   │
                  └────────┬────────┘
                           │  mint / burn to defend peg
                           ▼
                  ┌─────────────────┐
                  │   PegKeepers    │
                  └─────────────────┘
```

---

## Stack

- **Solidity** contracts, built and tested with **[Foundry](https://book.getfoundry.sh/getting-started/installation)** (Forge/Anvil).
- **Hardhat** + **TypeScript** for deployment scripts, local node forking, and protocol-state/action scripts.
- **Vyper** for select oracle components.
- OpenZeppelin upgradeable contracts.

## Getting Started

Install [Foundry](https://book.getfoundry.sh/getting-started/installation), then install dependencies:

```bash
forge install
npm install
```

## Tests

Foundry docs: https://book.getfoundry.sh/reference/forge/forge-test

```bash
forge test
```

Run all tests in a folder:

```bash
forge test --match-path test/USG/*.t.sol
```

- `-v` to `-vvvvv`: increase verbosity.
- `--fail-fast`: stop after the first failing test.

Coverage report:

```bash
npm run test:coverage
```

## Local Development

Run a node forked from mainnet:

```bash
npm run hh-node
```

Deploy the USG dev context to it:

```bash
npm run deploy:usg-local
```

### Test actions

Deposit collateral on all markets with test users:

```bash
npm run action:deposit-markets-USG
```

Borrow USG on all markets with test users:

```bash
npm run action:borrow-markets-USG
```

Advance the test node's clock, in days:

```bash
DAYS=3 npm run action:time-travel
```

Push rewards into markets (transferred directly, ahead of harvest/streaming):

```bash
npm run action:distribute-rewards-markets
```

Distribute USG rewards into vsTAN and start streaming:

```bash
npm run action:distribute-rewards-vsTan
```

## Liquidation Routing

Scripts under `js-scripts/hardhat/USG/routing/Curve` build and validate the swap routes used by the liquidation bot to unwind seized collateral.

Generate liquidation routes from `js-scripts/hardhat/USG/data/routes.csv` into `js-scripts/hardhat/USG/data/verifiedRoutes.json`:

```bash
npm run routing:generate-routes
```

Test the generated routes, writing results to `js-scripts/hardhat/USG/data/successRoutes.json`:

```bash
npm run routing:test-curve-routes
```

Hydrate a route template (`js-scripts/hardhat/USG/data/tplRoute.json`) with live addresses into `js-scripts/hardhat/USG/data/hydratedRoute.json` (the same script can also turn a `successRoutes.json` result back into a template):

```bash
npm run routing:hydrate-routes
```

## Vyper Setup

Some oracle components are written in Vyper. To install it via [rye](https://rye.astral.sh):

1. Install rye (on Windows, Scoop is the recommended package manager):

   ```bash
   scoop install rye
   ```

2. Create a `pyproject.toml`:

   ```toml
   [project]
   name = "tangent-contracts"
   version = "0.1.0"
   description = "Tangent Contracts for Foundry and Vyper"
   authors = [ { name = "Me", email = "me@local.org" } ]
   dependencies = [
       "vyper == 0.3.10"
   ]
   ```

3. Install:

   ```bash
   rye sync
   ```

4. Activate the virtual environment:

   ```bash
   source .venv/bin/activate
   ```

5. Verify:

   ```bash
   vyper --version
   ```

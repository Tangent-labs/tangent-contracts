# TgUSD

You need to have foundry in order to be able to work on this repo. [You can see this tutorial to install it](https://book.getfoundry.sh/getting-started/installation)

## Install dependencies

```
forge install
```

## Tests Commands

For more info : https://book.getfoundry.sh/reference/forge/forge-test

```
forge test
```

To run all tests in a folder :

```
forge test --match-path test/tgUSD/*.t.sol
```

**-v** : for the `--verbosity` part you can use up to 5 v from `-v` to `-vvvvv`
**--fail-fast** : stop running tests after the first failure.

## Run a node forked from mainnet

```
npm run hh-node
```

## Deploy the dev context of tgUSD

```
npm run deploy-tgUSD
```

## Actions

### Stake on markets

Stake some collateral on all markets with test users

```
npm run stake-markets-tgUSD
```

### Borrow tgUSD

Borrow some tgUSD on all markets with test users

```
npm run borrow-markets-tgUSD
```

### Pass some time

Increase the time on the test node in days basis.

```
DAYS=3 npm run time-travel
```

### Distribute rewards into all markets

Distribute rewards into markets in order to be processed. We are transfering rewards directly into markets before harvest and streaming.

```
npm run distribute-rewards-markets
```

### Distribute and streams tgUSD rewards into RsTan

Distribute rewards tgUSD into RsTan and start the streaming process.

```
npm run distribute-rewards-rsTan
```

### Swap in a Curve LP

- AMOUNT_IN is the float amount in number. The script takes into account decimals in.

```
LP=0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E AMOUNT_IN=100 I=0 J=1 npm run swap-curve
```

## Install vyper with rye

1. Install rye (Scoop is the recommended package manager for Windows developpers)

```bash
scoop install rye
```

2. Create a pyproject.toml file with the following content:

```toml
[project]
name = "tangent-contracts"
version = "0.1.0"
description = "Tangent Contracts for Foundry and Vyper"
authors = [ { name = "Me", email = "me@local.org" }]
dependencies = [
    "vyper == 0.3.10"
]
```

3. Run rye sync to install vyper

```bash
rye sync
```

4.  activate the virtual environment

```bash
source .venv/bin/activate
```

5. Test the vyper compiler

```bash
vyper --version
```

# Liquidation routes generation

## Generate Liquidation Routes

This script generates liquidation path from the `js-scripts\hardhat\tgUSD\data\routes.csv`,
and create the file `js-scripts\hardhat\tgUSD\data\verifiedRoutes.json`

```
npm run generate-routes
```

## Test Exchange Routes

This script tests the generated liquidation routes from `js-scripts\hardhat\tgUSD\data\verifiedRoutes.json` to
`js-scripts\hardhat\tgUSD\data\successRoutes.json`.

```
npm run test-exchange-routes
```

## Hydrate Route (2 ways)

This script takes a generated route with string `js-scripts\hardhat\tgUSD\data\tplRoute.json` and "hydrates" with addresses in `js-scripts\hardhat\tgUSD\data\hydratedRoute.json` that can be use by the liquidation bot.

by changing the script you can also take `js-scripts\hardhat\tgUSD\data\successRoutes.json` and make it a template `js-scripts\hardhat\tgUSD\data\tplRoute.json`

```
npm run hydrate-route
```

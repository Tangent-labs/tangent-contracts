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

### Distribute rewards into markets

Distribute rewards into markets in order to be processed. We are transfering rewards directly into markets before harvest

```
npm run distribute-rewards-tgUSD
```

### Swap in a Curve LP

- AMOUNT_IN is the float amount in number. The script takes into account decimals in.

```
LP=0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E AMOUNT_IN=100 I=0 J=1 npm run swap-curve
```

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

## Distribute some rewards into markets

```
npx hardhat run js-script/hardhat/tgUSD/distributeRewards/script.ts --network localhost
```

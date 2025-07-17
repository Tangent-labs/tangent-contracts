# Audit Scope

## Markets

3 différent types of market to audit + all the classes they inherit from. Please check the mermaid in ./documentation/archi/MarketClass.md for graph inheritance.

- ConvexCrvLPMarket
- ConvexFxnLPMarket
- BasicERC20Market

And the abstract contracts :

- Collateral
- DebtIR
- MarketCore
- MarketExternalActions
- PauseSettings

## Oracles

- OracleCryptoSwap
- OracleDuoPoolStable
- OracleCoinFromCurveLP
- OracleERC4626

## Tokens

- Tan
- USG
- VsTan
- WStable

## Utililities

- ControlTower
- IRCalculator
- MarketCreator
- WStable
- RewardAccumulator
- ZappingProxy

And the abstract contracts :

- LightOwnable
- ZappingUtil

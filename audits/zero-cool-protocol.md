# Zero Cool 29/01/2026

## Issues to fix

### Medium

- [x] - M-01 - OracleERC4626 mispricing of non-18 decimal ERC4626 shares enables over-borrow
- [x] - M-04 - VsTAN exits can be blocked by a non-transferable reward token

### Low

- [x] - L-01 - Deposits for address(0) create phantom collateral that permanently dilutes and blackholes market rewards
- [x] - L-03 - RewardAccumulator fee withdrawal can erase accounting if ERC20 transfer returns false
- [x] - L-06 - USG price oracle revert can freeze markets via mandatory IR checkpointing

### Info

- [x] - I01 - Reentrancy can corrupt transient token-index map and revert multi-claim/multi-process reward flows

## Need to think about it

- M-03 - Liquidation and seize paths rely on unbounded stale cached oracle prices
  - C'est le design
- M-07 - Debt index overflow freezes markets when checkpointIR multiplies before dividing
- L-05 - Amount/share rounding mismatch in repayAndWithdraw can bypass maxLTV by dust amounts

## No Fix

### Medium

- M-02 - Reward stream during zero collateral strands rewards permanently

  - We'll put a bit of collateral on each market to never be in totalCollat = 0

- M-05 - Reward dust recycling lets anyone repeatedly reset reward streaming to delay emissions
  - This will happen in any case. It's the standard design for the reward streaming in the industry
- M-06 - WStable over-mints against fee-bearing ERC4626 shares leading to insolvency and failed withdrawals

  - We’ll not pick fee bearing, Yearn vault with possible loss etc ...

- M08 - StakeDaoVaultV2Market assumes 1:1 asset:share ratio; unsafe if misconfigured with non-1:1 vault
  - StakeDao Vaults are 1:1 and if they put non 1:1 we’ll not take in collateral

### Low

- L-02 - RewardAccumulator removeReward permanently disables re-adding the same reward token and can strand accrued rewards
- removing reward from market is very exceptional, only if a reward is blocking the reward flux, if we need to do this, we’ll create a new market.

- L04 - PendlePTRouter cannot receive native ETH from SY redemption, breaking ETH-based swap paths
  - Known, no need this use case on our side

### Info

- I02 - Fee-on-transfer collateral is over-accounted allowing undercollateralized USG debt
- No collar with fee on transfer/withdraw

- I03 - Unchecked ERC20 returns allow unbacked wStable minting with non-compliant tokens
  - Only stable that are compliant will be picked for wStables

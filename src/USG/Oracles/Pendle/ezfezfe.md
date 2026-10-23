## Scope 1 (need soon): cvgCVX deprecation

**Repo:** convergence-contracts-ts
**Commit:** [e6a513a5](https://github.com/Tangent-labs/convergence-contracts-ts/commit/e6a513a54b0dd6ea178c2ee7c125e6b4814f9ad5)

**Context.** We are shutting down cvgCVX. The proxy at `0x2191DF768ad71140F9F3E96c1e4407A4aA31d082` gets upgraded to a new implementation, `CvgCVXKill`. Its only purpose is to pull the expired vlCVX locks out to the owner multisig (`0x11B6…6853`). There are few holders, so redemptions are paid **manually from that multisig**. There is no on-chain redemption queue.

**In scope**

- `contracts/Staking/Convex/cvgCVX/CvgCVXKill.sol`: a copy of `CvgCVX` plus one new function:
  - `withdrawForQueue()` (onlyOwner) calls `CVX_LOCKER.withdrawExpiredLocksTo(owner())`.

**What actually changes is about 10 lines.** A plain `diff CvgCVX.sol CvgCVXKill.sol` shows only the title, the contract name and `withdrawForQueue`.

**Operational sequence**

1. The multisig calls `setCapCvgCvx(0)`. This is what closes minting. ( already done )
2. ProxyAdmin (Treasury DAO) upgrades the proxy to `CvgCVXKill`.
3. The multisig calls `withdrawForQueue()` each time locks expire, then pays redeemers off-chain.
4. If a third party calls `kickExpiredLocks` on the locker, the CVX lands on the proxy. The multisig recovers it with `recoverTokens([CVX])`, which sends it to `cvgControlTower.convexTreasury()`. That is assumed to be the same multisig.

NOTE : - `contracts/Staking/Convex/cvgCVX/CvgCVX.sol`: updated to the last version deployed on mainnet (mintFees 25 → 50, relockUnlockableCVX()). This is only a repo sync, not a new change, and it is the baseline for the storage-layout comparison.

## Scope 2: Pendle PT as collateral

**Repo:** tangent-contracts
**Commit:** [4e4a2abe](https://github.com/Tangent-labs/tangent-contracts/commit/4e4a2abe6e57abdf0ec671abccd7f909c12a2681)

### 2a. `src/USG/Oracles/Pendle/OraclePendlePTLinearDiscount.sol` (audited before, updated)

**Change.** Previously `underlyingOracle` priced the SY's accounting asset directly. Now it must price the **SY yield token itself** (e.g. sUSDe, not USDe). The accounting asset price is derived as `syPrice * 10^exchangeRateScaleExp / SY.exchangeRate()`, and the linear discount is applied to that.

**Why.** The yield token can trade at a premium or discount to NAV. The old setup assumed it traded at NAV, so the market price is now reflected in the PT price.

**Other changes**

- Storage repacked into 2 slots, and `sy` is now stored.
- The constructor requires an 18-decimals underlying oracle.
- The constructor checks that the discount at deployment is below 100%.

### 2b. `src/USG/Routers/PendlePTRouter.sol` (audited before, fixes)

- **`swapTokenForPT`:** when `tokenIn == underlyingIn`, the Curve swap is skipped and the token is deposited straight into the SY. In that branch `msg.value` must be 0, otherwise the ETH would be stuck.
- **Native ETH blocked as SY input:** `underlyingIn == 0xEeee…` now reverts with `NativeUnderlyingNotSupported`. The SY deposit is not called with value and the router can't receive ETH.
- **`swapPTForPT` fix:** the intermediate underlying used to follow `crvRouterData._receiver`, so it could leave the router before the second leg. It is now forced to `address(this)` through an internal `_swapPTForToken(…, receiver)`.
- **Design note:** the router is stateless. Funds left on it can be taken by anyone.

### 2c. `src/USG/Oracles/Token/OracleERC4626FromCurveLP.sol` (NEW, never audited, ~70 lines)

**Purpose.** It gives a USD price for a "savings account" ERC4626 (e.g. USD3, sUSDS) at its **market** price rather than its NAV. These vaults have a redeem queue or limited instant liquidity, so NAV overstates what a liquidator can actually get. It is meant to be used as the `underlyingOracle` of 2a for those PTs.

**Mechanism**

- It reads a 2-coin Curve **StableSwap NG** pool (vault token / other coin).
- It uses `price_oracle(0)`, the EMA, and inverts it when the vault is coin 0.
- It removes the rate scaling with `stored_rates()`: `price = price_oracle * rate_vault / rate_other * 10^(decV - decO)`.
- It multiplies by `otherOracle`, which must price the other coin **itself**. If that coin is also a vault (e.g. sUSDS), the oracle prices sUSDS, not USDS.

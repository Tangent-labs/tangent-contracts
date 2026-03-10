# Liquidation Guide - Tangent Finance (USG Markets)

## Table of Contents

1. [Business Overview](#1-business-overview)
2. [Technical Details](#2-technical-details)
3. [Liquidation Examples](#3-liquidation-examples)

---

## 1. Business Overview

### How It Works

Tangent Finance allows users to deposit **collateral** (Curve LP tokens, ERC20 tokens, Pendle PT, etc.) into a **Market** and borrow **USG** (Tangent USD stablecoin) against it.

Each Market defines two key thresholds:

| Parameter              | Role                                                         | Example |
| ---------------------- | ------------------------------------------------------------ | ------- |
| **maxLTV**             | Maximum borrow ratio allowed at the time of borrowing        | 75%     |
| **liquidationThreshold** | Threshold below which the position becomes liquidatable   | 82%     |

The **gap** between `maxLTV` and `liquidationThreshold` acts as a safety buffer zone.

### Health Ratio

The **Health Ratio (HR)** measures the health of a position:

```
HR = (collateralBalance × collateralPrice × liquidationThreshold) / (userDebt × DENOMINATOR)
```

- **HR >= 1**: Healthy position, not liquidatable.
- **HR < 1**: Liquidatable position, anyone can liquidate.
- **HR = MAX_UINT**: No debt (fully healthy position).

### When Does a Position Become Liquidatable?

Two main scenarios:

1. **Collateral price drop**: The oracle (EMA) reflects the loss of value of the LP token or underlying asset.
2. **Debt increase**: Interest accrues, and the interest rate can spike if USG loses its peg (protection mechanism).

### The 3 Liquidation Modes

| Mode               | Who?             | Condition                              | Description                                                    |
| ------------------ | ---------------- | -------------------------------------- | -------------------------------------------------------------- |
| **liquidate**      | Anyone           | HR < 1                                 | The liquidator repays the debt in USG and receives the collateral. If a router is provided, the collateral is swapped to USG — the surplus after repayment is the liquidator's profit in USG. |
| **selfLiquidate**  | The owner        | None (always possible)                 | The user liquidates their own position                         |
| **seizeCollateral**| Anyone           | Collateral value < debt (bad debt)     | The collateral is sent to the DAO treasury                     |

### Liquidation Fee

The `liquidationFee` is a **fee charged by the protocol on the liquidator's gains**. It only applies when the value of the liquidated collateral exceeds the repaid debt (i.e., when the liquidator makes a profit).

```
fee = liquidationFee × (collatValue - usgToRepay) / DENOMINATOR
```

- `DENOMINATOR` = 100,000 (precision to 0.001%)
- This fee is minted as USG and sent to the protocol's `feeTreasury`.
- If the collateral value is less than the debt, no fee is charged.

The `liquidationFee` is configurable per market and can be read on-chain via `market.liquidationFee()`.

### Calculating Liquidation Profitability

Before executing a liquidation, it's important to estimate the net profit:

```
collatValue     = collateralBalance × collateralPrice / 10^collatDecimals
gross_profit    = collatValue - userDebt
protocol_fee    = liquidationFee × gross_profit / 100_000
net_profit      = gross_profit - protocol_fee - gas_cost - swap_slippage
```

**Concrete Example — USDC_USDT Market (Convex Curve LP)**

Market configuration: `liquidationThreshold = 93%`, `maxLTV = 92.5%`

A user deposited 10,000 LP USDC/USDT and borrowed 9,200 USG (LTV of 92%).
Following a slight LP depeg, the oracle price drops from 1.00 to 0.98 USD/token.

| Data                                  | Calculation                                | Value         |
| ------------------------------------- | ------------------------------------------ | ------------- |
| Market                                |                                            | USDC_USDT     |
| Collateral                            | LP USDC/USDT (Convex Curve)                | 10,000 tokens |
| Oracle price (after depeg)            |                                            | 0.98 USD      |
| Collateral value                      | 10,000 × 0.98                              | 9,800 USG     |
| Health Ratio                          | 9,800 × 93% / 9,200 = 0.990               | **< 1 = liquidatable** |
| User debt (with interest)             |                                            | 9,200 USG     |
| Gross profit                          | 9,800 - 9,200                              | 600 USG       |
| liquidationFee (5%)                   | 5% × 600                                   | 30 USG        |
| Swap slippage LP → USG (~0.3%)        | 0.3% × 9,800                               | ~29.4 USG     |
| Gas (~500k gas, 30 gwei)              |                                            | ~5 USD        |
| **Net profit**                        | 600 - 30 - 29.4 - 5                        | **~535.6 USG** |

**Key Considerations:**

- Profit depends directly on the **spread between collateral value and debt**. The lower the HR, the larger the spread.
- **Slippage** on the swap (collateral → USG) reduces profit. Exotic or illiquid LP tokens will have higher slippage.
- For **partial liquidations**, profit is proportional to the fraction liquidated.
- A position in **bad debt** (collateral value < debt) is not profitable for a standard liquidator — it falls under `seizeCollateral()` (sent to DAO treasury).
- On stable markets (USDC_USDT, crvUSD_USDC), the gap `liquidationThreshold - maxLTV` is very small (0.5-1%), so liquidation opportunities arise quickly after a depeg but with reduced margins.

---

## 2. Technical Details

### Contracts Involved in Liquidation

These are the contracts that come into play during a liquidation. Each Market inherits from `MarketExternalActions` and `MarketCore`, while `MarketViewer` and `ZappingProxy` are utility contracts shared across all Markets.

| Contract                              | Role                                                           |
| ------------------------------------- | -------------------------------------------------------------- |
| `MarketExternalActions.sol`           | **Entry point** — Exposes the public functions `liquidate()`, `selfLiquidate()` and `seizeCollateral()`. This is the contract the liquidator calls directly (each Market inherits from it). |
| `MarketCore.sol`                      | **Internal logic** — Contains the Health Ratio calculation, debt/collateral allocation, liquidation fee computation, and flow orchestration (`_liquidate()` → `_postLiquidate()`). Not called directly. |
| `MarketViewer.sol`                    | **On-chain read** — View-only contract for querying position state: `healthRatio()`, `userDebt()`, `positionValue()`. Used to identify liquidatable positions. |
| `ZappingProxy.sol`                    | **Swap proxy** — Receives collateral from the Market, approves the swap router (Enso, Curve, etc.), executes the collateral → USG swap, and verifies that `minAmountOut` is respected. Only involved when `router != address(0)`. |

### Checking if a Position is Liquidatable

#### Via `MarketViewer`

**Solidity:**

```solidity
IMarketViewer marketViewer = IMarketViewer(MARKET_VIEWER_ADDRESS);

// Health Ratio (base 1e18) — liquidatable if < 1e18
uint256 hr = marketViewer.healthRatio(marketAddress, accountAddress);

// User debt (in USG, including accrued interest)
uint256 debt = marketViewer.userDebt(IDebtIR(marketAddress), accountAddress);

// Collateral value in USD (precision 1e18)
uint256 value = marketViewer.positionValue(ICollateral(marketAddress), accountAddress);
```

**TypeScript (ethers.js):**

```typescript
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider(RPC_URL);

const marketViewer = new ethers.Contract(MARKET_VIEWER_ADDRESS, [
  "function healthRatio(address market, address account) view returns (uint256)",
  "function userDebt(address market, address account) view returns (uint256)",
  "function positionValue(address market, address account) view returns (uint256)",
], provider);

const hr = await marketViewer.healthRatio(marketAddress, accountAddress);
const debt = await marketViewer.userDebt(marketAddress, accountAddress);
const value = await marketViewer.positionValue(marketAddress, accountAddress);

const isLiquidatable = hr < ethers.parseEther("1");
console.log(`HR: ${ethers.formatEther(hr)} — Liquidatable: ${isLiquidatable}`);
```

### Liquidating a Position

There are two ways to call `liquidate()`, depending on whether you already hold USG or not:

1. **Without router (direct)** — You already have enough USG to repay the debt. The collateral is sent directly to `msg.sender`. Pass `router = address(0)` and `routerCall = ""`.

2. **With router (via ZappingProxy)** — You don't have USG: the collateral is sent to the ZappingProxy which swaps it for USG via the specified router. The resulting USG is used to repay the debt. Use the Enso API to build the route.

> **Important**: The collateral-to-USG swap is **not handled by Tangent**. It is the liquidator's responsibility to provide a valid and profitable swap route.

#### Swap Responsibility: The Liquidator's

A liquidation involves converting the recovered collateral to USG to repay the debt. **This swap is not handled by Tangent**: the protocol delegates this operation to an **external router** provided by the liquidator.

Concretely, the liquidator passes a `ZapStruct` containing:
- `router`: the address of the contract that will execute the swap
- `routerCall`: the encoded calldata of the swap transaction

Tangent's `ZappingProxy` only handles:
1. Sending the collateral to the router
2. Approving the router to spend the tokens
3. Verifying that `minAmountOut` is respected after the swap

**Any swap contract can be used** (Curve Router, Uniswap Router, 1inch, Paraswap, etc.), as long as it accepts the input tokens and returns USG to the receiver. Our recommendation is to use the **Enso API** which automatically aggregates the best multi-DEX routes, but this is not mandatory.

#### Call Structs for `liquidate()`

```solidity
struct LiquidateIn {
    address account;                    // Address of the borrower to liquidate (position = market + borrower)
    PostLiquidate postLiquidate;        // Liquidation parameters
    uint256 minCollatValueToLiquidate;  // Minimum value in $ to liquidate (protection)
}

struct PostLiquidate {
    uint256 collatAmountToLiquidate;    // Amount of collateral to liquidate
    uint256 minUsgOut;                  // Min USG received after swap (if via ZappingProxy)
    uint256 maxUsgToBurn;               // Max USG burned from msg.sender
    uint256 minCollatAmountToLiquidate; // Min collateral actually liquidated (front-running protection, see below)
    bool isReceiptOut;                  // true = receipt token, false = underlying
}

struct ZapStruct {
    address router;     // Router address (Curve, etc.) — address(0) if no swap
    bytes routerCall;   // Encoded calldata for the router
}
```

| Parameter | Description |
| --- | --- |
| `liquidateIn.account` | Address of the borrower to liquidate. The position is identified by the `market + borrower` pair. |
| `liquidateIn.postLiquidate.collatAmountToLiquidate` | Amount of collateral to liquidate. If >= borrower's balance, full liquidation. |
| `liquidateIn.postLiquidate.minUsgOut` | Minimum amount of USG received after swap via ZappingProxy. `0` if no router. **Warning**: if this parameter is too low or set to `0` during a swap, an attacker can sandwich your transaction (front-run + back-run) to manipulate the pool price and make you receive far less USG than expected. You would then lose part — or all — of your liquidation profit. Always use the `amountOut` returned by the Enso API with a reasonable slippage (e.g., `amountOut * 99 / 100` for 1%). |
| `liquidateIn.postLiquidate.maxUsgToBurn` | Maximum amount of USG burned from `msg.sender`. Protection against unexpected cost. |
| `liquidateIn.postLiquidate.minCollatAmountToLiquidate` | Minimum amount of collateral actually liquidated. **Front-running protection**: if another liquidator executes before you and reduces the borrower's balance, the contract adjusts `collatAmountToLiquidate` to the remaining balance. If this adjusted amount is less than `minCollatAmountToLiquidate`, the tx reverts — preventing an unprofitable liquidation. Recommended: pass the borrower's `collateralBalance`. |
| `liquidateIn.postLiquidate.isReceiptOut` | `true` = receive the receipt token (staking wrapper), `false` = receive the underlying token. |
| `liquidateIn.minCollatValueToLiquidate` | Minimum USD value of the liquidated collateral. Protection against a price drop between submission and execution. |
| `liquidationCall.router` | Swap router address. `address(0)` if no swap (collateral sent directly to the liquidator). |
| `liquidationCall.routerCall` | Encoded calldata for the router (obtained via Enso API). Empty if no router. |


#### Internal Liquidation Flow

```
liquidate() called by the liquidator
    │
    ├─ _preLiquidate() → checkpoint IR, compute current debt
    ├─ Health Ratio check → revert if >= 1e18
    ├─ _liquidate()
    │     ├─ Full or Partial liquidation
    │     ├─ Fee computation on profit
    │     └─ _postLiquidate()
    │           ├─ If router == address(0):
    │           │     └─ Collateral sent directly to the liquidator (msg.sender)
    │           ├─ If router != address(0):
    │           │     ├─ Collateral sent to ZappingProxy
    │           │     └─ ZappingProxy swaps collateral → USG via the router
    │           └─ _burnUSG(msg.sender, usgToRepay + fee)
    └─ Mint fee as USG to feeTreasury
```

#### Partial vs. Full Liquidation

- **Full**: `collatAmountToLiquidate >= collateralBalance` → the entire position is liquidated.
- **Partial**: The repaid debt is proportional to the liquidated collateral. The remaining debt must respect the market's `minimumLoan`.


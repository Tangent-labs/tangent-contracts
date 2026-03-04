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

#### Call Examples

##### Direct Mode (no router) — The Liquidator Holds USG

**Solidity**

```solidity
import {IMarketCore} from "src/interfaces/internals/USG/IMarketCore.sol";
import {ZapStruct} from "src/interfaces/internals/ICommonStruct.sol";

// Prerequisite: the liquidator has approved the market to spend their USG
// usg.approve(address(market), type(uint256).max);

uint256 collatBalance = market.collateralBalances(borrower);

market.liquidate(
    LiquidateIn({
        account: borrower,
        postLiquidate: PostLiquidate({
            collatAmountToLiquidate: collatBalance,   // full liquidation
            minUsgOut: 0,                              // no swap
            maxUsgToBurn: type(uint256).max,            // accept burning all necessary USG
            minCollatAmountToLiquidate: collatBalance,  // revert if front-run
            isReceiptOut: false
        }),
        minCollatValueToLiquidate: 0
    }),
    ZapStruct({
        router: address(0),   // no router → collateral sent directly
        routerCall: ""
    })
);
```

**TypeScript (ethers v6)**

```typescript
const collatBalance = await market.collateralBalances(borrower);

const tx = await market.liquidate(
  {
    account: borrower,
    postLiquidate: {
      collatAmountToLiquidate: collatBalance,
      minUsgOut: 0n,
      maxUsgToBurn: ethers.MaxUint256,
      minCollatAmountToLiquidate: collatBalance,
      isReceiptOut: false,
    },
    minCollatValueToLiquidate: 0n,
  },
  {
    router: ethers.ZeroAddress,
    routerCall: "0x",
  }
);
await tx.wait();
```

##### With Router (swap collateral → USG via ZappingProxy)

The liquidator does not hold USG. The collateral is first sent to the ZappingProxy, which swaps it for USG via the provided route.

**1. Build the Route with the Enso API**

```typescript
// Get the ZappingProxy address from the market
const zappingProxy = await market.zappingProxy();

const params = new URLSearchParams({
  chainId: "1",
  fromAddress: zappingProxy,           // The ZappingProxy executes the swap
  spender: zappingProxy,
  tokenIn: collateralTokenAddress,
  tokenOut: usgAddress,
  amountIn: collatBalance.toString(),
  slippage: "100",                     // 1% slippage (in bps)
});

const res = await fetch(`https://api.enso.finance/api/v1/shortcuts/route?${params}`, {
  headers: { Authorization: "Bearer YOUR_API_KEY" },
});
const route = await res.json();
// route.tx.to   → router address
// route.tx.data → calldata for the swap
```

**2. Call liquidate() with the Route**

**Solidity**

```solidity
// router and routerCall obtained via the Enso API
market.liquidate(
    LiquidateIn({
        account: borrower,
        postLiquidate: PostLiquidate({
            collatAmountToLiquidate: collatBalance,
            minUsgOut: minUsgExpected,             // slippage protection on the swap
            maxUsgToBurn: type(uint256).max,
            minCollatAmountToLiquidate: collatBalance,
            isReceiptOut: false
        }),
        minCollatValueToLiquidate: 0
    }),
    ZapStruct({
        router: ensoRouterAddress,     // route.tx.to
        routerCall: ensoRouterCalldata // route.tx.data
    })
);
```

**TypeScript (ethers v6)**

```typescript
const tx = await market.liquidate(
  {
    account: borrower,
    postLiquidate: {
      collatAmountToLiquidate: collatBalance,
      minUsgOut: minUsgExpected,
      maxUsgToBurn: ethers.MaxUint256,
      minCollatAmountToLiquidate: collatBalance,
      isReceiptOut: false,
    },
    minCollatValueToLiquidate: 0n,
  },
  {
    router: route.tx.to,        // Enso router address
    routerCall: route.tx.data,  // swap calldata
  }
);
await tx.wait();
```

---

## 3. Liquidation Examples

### Building the Swap Route with the Enso API

For both examples below, it is **recommended to use the Enso API** to automatically build the optimal swap route (collateral → USG). Enso is a DeFi aggregator that computes the best multi-hop path taking into account liquidity across all DEXes.

**Enso Documentation**: https://docs.enso.build

#### API Call to Get the Route

**curl:**

```bash
# GET /api/v1/shortcuts/route
curl -X 'GET' \
  'https://api.enso.finance/api/v1/shortcuts/route?\
chainId=1&\
fromAddress=<ZAPPING_PROXY_ADDRESS>&\
receiver=<LIQUIDATOR_ADDRESS>&\
spender=<ZAPPING_PROXY_ADDRESS>&\
amountIn=<COLLAT_AMOUNT_IN_WEI>&\
slippage=300&\
tokenIn=<COLLAT_TOKEN_ADDRESS>&\
tokenOut=<USG_ADDRESS>&\
routingStrategy=router' \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer <ENSO_API_KEY>'
```

**TypeScript:**

```typescript
async function getEnsoRoute(
  collatTokenAddress: string,
  collatAmountWei: string,
  zappingProxy: string,
  liquidatorAddress: string,
  usgAddress: string,
): Promise<{ to: string; data: string; amountOut: bigint }> {
  const params = new URLSearchParams({
    chainId: "1",
    fromAddress: zappingProxy,
    receiver: liquidatorAddress,
    spender: zappingProxy,
    amountIn: collatAmountWei,
    slippage: "300",
    tokenIn: collatTokenAddress,
    tokenOut: usgAddress,
    routingStrategy: "router",
  });

  const res = await fetch(
    `https://api.enso.finance/api/v1/shortcuts/route?${params}`,
    { headers: { Authorization: `Bearer ${process.env.ENSO_API_KEY}` } },
  );
  const { tx, amountOut } = await res.json();
  return { to: tx.to, data: tx.data, amountOut: BigInt(amountOut) };
}
```

#### API Response

The API returns a ready-to-use `tx` object:

```json
{
  "tx": {
    "to": "0x...",       // Enso router address
    "data": "0x...",     // Encoded calldata for the swap
    "value": "0"
  },
  "amountOut": "5200000000000000000000"
}
```

The `tx.to` and `tx.data` fields map directly to the `ZapStruct`:

```solidity
ZapStruct({
    router: tx.to,        // Router returned by Enso
    routerCall: tx.data   // Calldata returned by Enso
})
```

> **Important**: The `fromAddress` and `spender` must be the `ZappingProxy` address, as it is the one that temporarily holds the collateral and approves the router for the swap.

---

### Example A: Liquidation by Swapping Collateral for USG

In this scenario, the liquidator **does not need to hold USG beforehand**. The recovered collateral is swapped for USG via a router (route built by Enso), and the resulting USG is used to repay the debt.

#### Scenario

- Market: `ConvexCrvLP` (collateral = LP USDC/crvUSD)
- Position: 5,000 LP tokens deposited, 4,250 USG borrowed
- The HR dropped below 1 due to interest accumulation

#### Steps

**1. Check that the position is liquidatable**

**2. Get the swap route via the Enso API** (off-chain)

**3. Execute the liquidation on-chain** with the `ZapStruct` built from the Enso response

#### Full Code — TypeScript (ethers.js)

```typescript
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

const MARKET_ABI = [
  "function liquidate((address account, (uint256 collatAmountToLiquidate, uint256 minUsgOut, uint256 maxUsgToBurn, uint256 minCollatAmountToLiquidate, bool isReceiptOut) postLiquidate, uint256 minCollatValueToLiquidate) liquidateIn, (address router, bytes routerCall) liquidationCall)",
  "function collateralBalances(address) view returns (uint256)",
  "function collatToken() view returns (address)",
];
const VIEWER_ABI = [
  "function healthRatio(address market, address account) view returns (uint256)",
  "function userDebt(address market, address account) view returns (uint256)",
];

const market = new ethers.Contract(MARKET_ADDRESS, MARKET_ABI, signer);
const viewer = new ethers.Contract(MARKET_VIEWER_ADDRESS, VIEWER_ABI, provider);

// 1. Check the position
const hr = await viewer.healthRatio(MARKET_ADDRESS, TARGET_ACCOUNT);
if (hr >= ethers.parseEther("1")) {
  console.log("Position not liquidatable");
  process.exit(0);
}

const collatAmount = await market.collateralBalances(TARGET_ACCOUNT);
const collatToken = await market.collatToken();
const debt = await viewer.userDebt(MARKET_ADDRESS, TARGET_ACCOUNT);
console.log(`HR: ${ethers.formatEther(hr)} | Debt: ${ethers.formatEther(debt)} USG | Collat: ${collatAmount}`);

// 2. Get the Enso route
const ensoRoute = await getEnsoRoute(collatToken, collatAmount.toString(), ZAPPING_PROXY, signer.address, USG_ADDRESS);

// 3. Execute the liquidation
const tx = await market.liquidate(
  {
    account: TARGET_ACCOUNT,
    postLiquidate: {
      collatAmountToLiquidate: collatAmount,
      minUsgOut: (ensoRoute.amountOut * 99n) / 100n,  // 1% slippage
      maxUsgToBurn: ethers.MaxUint256,
      minCollatAmountToLiquidate: collatAmount,
      isReceiptOut: false,
    },
    minCollatValueToLiquidate: 0,
  },
  {
    router: ensoRoute.to,
    routerCall: ensoRoute.data,
  },
);

const receipt = await tx.wait();
console.log(`Liquidation executed — tx: ${receipt.hash}`);
```

#### Solidity Code (on-chain only)

```solidity
uint256 hr = marketViewer.healthRatio(address(market), targetAccount);
require(hr < 1 ether, "Position not liquidatable");

uint256 collatAmount = market.collateralBalances(targetAccount);

// router & routerCall are built off-chain via the Enso API
market.liquidate(
    LiquidateIn({
        account: targetAccount,
        postLiquidate: PostLiquidate({
            collatAmountToLiquidate: collatAmount,
            minUsgOut: minUsgFromEnso,
            maxUsgToBurn: type(uint256).max,
            minCollatAmountToLiquidate: collatAmount,
            isReceiptOut: false
        }),
        minCollatValueToLiquidate: 0
    }),
    ZapStruct({
        router: ensoRouter,
        routerCall: ensoCalldata
    })
);
```

#### What Happens Under the Hood

1. The Market withdraws the collateral from the underlying protocol (Convex/Curve).
2. The collateral is sent to the `ZappingProxy`.
3. The `ZappingProxy` approves the Enso router and executes the swap: collateral → ... → USG.
4. The resulting USG is sent to `msg.sender` (the liquidator).
5. The Market burns `usgToRepay + fee` from `msg.sender`.
6. The USG surplus (collateral value - debt - fee) stays with the liquidator = **profit**.

#### Liquidator's Profit

```
profit = USG received from swap - USG burned (debt + fee)
```

---

### Example B: Liquidation with FlashLoan

In this scenario, the liquidator borrows USG via a flash loan, repays the debt, receives the collateral directly, then resells it to repay the flash loan.

#### Scenario

- Market: `BasicERC20Market` (Pendle PT) or any other market
- The liquidator wants full control over the collateral swap

#### Concept

```
┌──────────────────────────────────────────────────────┐
│                   Flash Loan Flow                    │
│                                                      │
│  1. Borrow USG via flash loan (Aave, Balancer...)    │
│  2. Approve USG on the Market                        │
│  3. Call market.liquidate() WITHOUT router            │
│     → USG burned, collateral received directly       │
│  4. Swap collateral → USG (via Enso, Curve, etc.)    │
│  5. Repay flash loan + fee                           │
│  6. Keep the surplus = profit                        │
└──────────────────────────────────────────────────────┘
```

#### Solidity Contract — FlashLoanLiquidator

The flash loan requires a deployed smart contract that receives the callback:

```solidity
contract FlashLoanLiquidator {
    address public immutable ensoRouter;

    constructor(address _ensoRouter) {
        ensoRouter = _ensoRouter;
    }

    /// @notice Flash loan provider callback (ERC-3156)
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        (address market, address account, uint256 collatAmount, bytes memory swapData)
            = abi.decode(data, (address, address, uint256, bytes));

        // 1. Approve USG on the market
        IERC20(token).approve(market, type(uint256).max);

        // 2. Liquidate WITHOUT router (router = address(0))
        //    Collateral is sent directly to address(this)
        IMarket(market).liquidate(
            LiquidateIn({
                account: account,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: collatAmount,
                    minUsgOut: 0,           // No swap via ZappingProxy
                    maxUsgToBurn: amount,    // Max = flash loan amount
                    minCollatAmountToLiquidate: collatAmount,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            ZapStruct({
                router: address(0),     // No router = direct collateral
                routerCall: ""
            })
        );

        // 3. Swap collateral → USG via route built off-chain (Enso API)
        IERC20 collatToken = ICollateral(market).collatToken();
        uint256 collatBal = collatToken.balanceOf(address(this));
        collatToken.approve(ensoRouter, collatBal);
        (bool success, ) = ensoRouter.call(swapData);
        require(success, "Swap failed");

        // 4. Approve flash loan repayment
        IERC20(token).approve(msg.sender, amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
```

#### Off-chain Orchestration — TypeScript (ethers.js)

The off-chain script prepares the Enso route, encodes the data, and triggers the flash loan:

```typescript
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

const viewer = new ethers.Contract(MARKET_VIEWER_ADDRESS, VIEWER_ABI, provider);
const market = new ethers.Contract(MARKET_ADDRESS, MARKET_ABI, provider);
const flashLoanLiquidator = new ethers.Contract(FLASH_LIQUIDATOR_ADDRESS, FLASH_LIQUIDATOR_ABI, signer);
const flashLoanProvider = new ethers.Contract(FLASH_LOAN_PROVIDER, FLASH_LOAN_ABI, signer);

// 1. Check the position
const hr = await viewer.healthRatio(MARKET_ADDRESS, TARGET_ACCOUNT);
if (hr >= ethers.parseEther("1")) {
  console.log("Position not liquidatable");
  process.exit(0);
}

const collatAmount = await market.collateralBalances(TARGET_ACCOUNT);
const collatToken = await market.collatToken();
const debt = await viewer.userDebt(MARKET_ADDRESS, TARGET_ACCOUNT);

// 2. Get the Enso route for the collateral → USG swap
//    fromAddress = the FlashLoanLiquidator (it holds the collateral after liquidation)
const ensoRoute = await getEnsoRoute(
  collatToken,
  collatAmount.toString(),
  FLASH_LIQUIDATOR_ADDRESS,  // The contract that holds the collateral
  FLASH_LIQUIDATOR_ADDRESS,  // The USG receiver
  USG_ADDRESS,
);

// 3. Encode the data for the callback
const callbackData = ethers.AbiCoder.defaultAbiCoder().encode(
  ["address", "address", "uint256", "bytes"],
  [MARKET_ADDRESS, TARGET_ACCOUNT, collatAmount, ensoRoute.data],
);

// 4. Trigger the flash loan
const tx = await flashLoanProvider.flashLoan(
  FLASH_LIQUIDATOR_ADDRESS,  // Flash loan receiver
  USG_ADDRESS,                // Borrowed token
  debt,                       // Amount to borrow
  callbackData,               // Data passed to the callback
);

const receipt = await tx.wait();
console.log(`Flash loan liquidation — tx: ${receipt.hash}`);
```

#### Direct Call Without Flash Loan (if the Liquidator Already Holds USG)

When `router == address(0)` in the `ZapStruct`, the collateral is sent directly to `msg.sender`. The liquidator must **already have USG**:

**Solidity:**

```solidity
usg.approve(address(market), type(uint256).max);

market.liquidate(
    LiquidateIn({
        account: targetAccount,
        postLiquidate: PostLiquidate({
            collatAmountToLiquidate: collatAmount,
            minUsgOut: 0,
            maxUsgToBurn: type(uint256).max,
            minCollatAmountToLiquidate: collatAmount,
            isReceiptOut: false
        }),
        minCollatValueToLiquidate: 0
    }),
    ZapStruct({router: address(0), routerCall: ""})
);
// The liquidator receives the collateral directly
```

**TypeScript:**

```typescript
// Approve USG
const usg = new ethers.Contract(USG_ADDRESS, ["function approve(address,uint256)"], signer);
await (await usg.approve(MARKET_ADDRESS, ethers.MaxUint256)).wait();

// Liquidate without router
const tx = await market.liquidate(
  {
    account: TARGET_ACCOUNT,
    postLiquidate: {
      collatAmountToLiquidate: collatAmount,
      minUsgOut: 0,
      maxUsgToBurn: ethers.MaxUint256,
      minCollatAmountToLiquidate: collatAmount,
      isReceiptOut: false,
    },
    minCollatValueToLiquidate: 0,
  },
  { router: ethers.ZeroAddress, routerCall: "0x" },
);
await tx.wait();
// Collateral received directly, swap later via Enso or other
```

#### 

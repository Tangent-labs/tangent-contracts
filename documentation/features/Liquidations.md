# Liquidations

A loan position is considered as liquidable when the health Ratio is inferior to 1.

When a position is liquidable, any account can call the **liquidate** function on the associated _market_ contract.

This function takes into parameters :

- **address** _account_ :
- **uint256** _tgUSDToRepay_ :
- **address** _liquidator_ :
- **bytes** _liquidationCall_ :

## Schemas

- 🔴 Collateral
- 🟢 tgUSD

### With liquidator

```mermaid
sequenceDiagram
    UnderlyingProtocol->>Market:🔴 Withdraw from Underlying protocol
    Market->>LiquidatorProxy :🔴 Send to the Liquidator proxy
    LiquidatorProxy->>Liquidator : 🔴 Send for dumping
    Liquidator->>Sender: 🟢 Receives tgUSD
    Sender->> 0x000 : 🟢 Burn the debt equivalent in tgUSD

```

### Without liquidator

```mermaid
sequenceDiagram
    UnderlyingProtocol->>Market: 🔴 Withdraw from Underlying protocol
    Market->>Sender : 🔴 Send to the sender
    Sender->> 0x000 : 🟢 Burn the debt equivalent in tgUSD.
```

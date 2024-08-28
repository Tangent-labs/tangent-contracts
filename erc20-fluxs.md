# ERC20 fluxes

## Deposit
### Deposit with stable not crvUSD

```mermaid
sequenceDiagram
    User->>LendSplitter: Transfers USDC
    LendSplitter->>CurvePool:Swap USDC
    CurvePool->>LendSplitter:Receive crvUSD after swap
    LendSplitter->>LlamaLend:Stake the crvUsd in LlamaLend
    0x00 ->>LendSplitter:Receive cvCRVUSD
    LendSplitter->>StakeDaoGauge:Stake cvCRVUSD in StakeDao
    0x00->>LendSplitter:Receive gaugeAsset
    0x00->>User: Receive gUSD/scvUSD
```

### Deposit with crvUSD

```mermaid
sequenceDiagram
    User->>LendSplitter: Send crvUSD 
    LendSplitter->>LlamaLend:Stake the crvUsd in LlamaLend
    0x00 ->>LendSplitter:Receive cvCRVUSD
    LendSplitter->>StakeDaoGauge:Stakes cvCRVUSD in StakeDao
    0x00->>LendSplitter:Receive StakeDao gaugeAsset
    0x00->>User: Receive gUSD/scvUSD
```

### Deposit with Llamalend deposit proof

```mermaid
sequenceDiagram
    User ->>LendSplitter: Send cvCRVUSD
    LendSplitter->>StakeDaoGauge:Stakes cvCRVUSD in StakeDao
    0x00->>LendSplitter:Receive StakeDao gaugeAsset
    
    0x00->>User: Receive gUSD/scvUSD
```

### Deposit with StakeDao gauge asset

```mermaid
sequenceDiagram
    User->>LendSplitter: Send StakeDao gaugeAsset
    0x00->>User: Receive gUSD/scvUSD
```

## Reward Processing

### Process Governance Rewards

```mermaid
sequenceDiagram
    GaugeLlamaLend->>GaugeStakeDao : Harvest GovRewards from Llamalend gauge
    GaugeStakeDao->>gUSD:  Claim GovRewards from StakeDao gauge
    gUSD->>YieldSplitter: Process Rewards & stream GovRewards

```
## Claiming 

### Claim Governance Rewards

```mermaid
sequenceDiagram
    YieldSplitter->>User : Receive Gov Rewards

```

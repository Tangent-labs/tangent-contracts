# Existing contract

## StakeDao deposit usecase

```mermaid
sequenceDiagram
    participant User
    participant Vault
    participant ERC20 as LP Token
    participant Strategy
    participant LiquidityGauge as Reward Distributor Gauge

    User->>Vault: deposit(_receiver, _amount, _doEarn)
    Vault->>ERC20: safeTransferFrom(User, Vault, _amount)
    alt if _doEarn is false
        Vault->>Vault: Calculate incentive fee
        Vault->>Vault: Subtract incentive from _amount
        Vault->>Vault: Add incentive to total incentive token amount
    else
        Vault->>Vault: Add total incentive token amount to _amount
        Vault->>Vault: Reset incentive token amount
        Vault->>Vault: _earn()
        Vault->>Strategy: deposit(LP Token, _balance)
    end
    Vault->>Vault: _mint(Vault, _amount)
    Vault->>LiquidityGauge: deposit(_amount, _receiver)
    Note over User: Receiver's account credited in Reward Distributor Gauge
```

## StakeDao Withdraw usecase

```mermaid
sequenceDiagram
    participant User
    participant Vault
    participant ERC20 as LP Token
    participant Strategy
    participant LiquidityGauge as Reward Distributor Gauge

    User->>Vault: withdraw(_shares)
    Vault->>LiquidityGauge: balanceOf(User)
    alt if shares requested <= balance
        LiquidityGauge->>Vault: withdraw(_shares, User, true)
        Vault->>Vault: _burn(Vault, _shares)
        Vault->>Vault: Check available LP Token balance
        Vault->>ERC20: balanceOf(Vault)
        alt if shares > available tokens
            Vault->>Strategy: withdraw(LP Token, needed amount)
        end
        Vault->>ERC20: safeTransfer(User, _shares)
    else
        Vault-->>User: NOT_ENOUGH_TOKENS()
    end

```

## Curve Deposit usecase

```mermaid
sequenceDiagram
    participant User
    participant Vault
    participant ERC20 as ERC20 (Borrowed Token)
    participant Controller

    User->>Vault: deposit(assets, receiver)
    Note over Vault: Verify enough assets can be added
    Vault->>Vault: _total_assets()
    Vault->>ERC20: balanceOf(Controller)
    Vault->>Controller: total_debt()
    Vault->>Vault: _convert_to_shares(assets, true)
    Note over Vault: Calculate shares to mint
    Vault->>ERC20: transferFrom(User, Controller, assets)
    Note over ERC20: Transfer assets from user to controller
    Vault->>Vault: _mint(receiver, to_mint)
    Note over Vault: Mint new shares to receiver
    Controller->>Controller: save_rate()
    Note over Vault: Optionally update rates in Controller
    Note over User: Receiver credited with new shares

```

## Curve Withdraw usecase

```mermaid
sequenceDiagram
    participant User
    participant Vault
    participant ERC20 as ERC20 (Borrowed Token)
    participant Controller

    User->>Vault: withdraw(assets, receiver, owner)
    Note over Vault: Verify sufficient assets are available
    Vault->>Vault: _total_assets()
    Vault->>ERC20: balanceOf(Controller)
    Vault->>Controller: total_debt()
    Vault->>Vault: _convert_to_shares(assets, false)
    Note over Vault: Calculate shares to burn
    alt If owner != msg.sender
        Vault->>Vault: Check allowance of owner for msg.sender
        Note right of Vault: Adjust allowance if needed
    end
    Vault->>Vault: _burn(owner, shares)
    Note over Vault: Burn the corresponding shares from owner's balance
    Vault->>ERC20: transferFrom(Controller, receiver, assets)
    Note over ERC20: Transfer assets from controller to receiver
    Controller->>Controller: save_rate()
    Note over Vault: Optionally update rates in Controller
    Note over User: Receiver gets the assets, shares are burned

```

# Ressources

## Tools

- Abi to solidity interface code : https://bia.is/tools/abi2solidity/

## Contracts

## Stake DAO

https://www.stakedao.org/yield?chainId=1&protocol=llamalend

- Vault : https://etherscan.io/address/0xfa6D40573082D797CB3cC378c0837fB90eB043e5#code
- LP : https://etherscan.io/address/0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA#code
- Gauge (StakeDAO) : https://etherscan.io/address/0xFCc5a1B4e3d80Ce459e346A0b8F63b655ED709cb#code
- Gauge (Curve) : https://etherscan.io/address/0x49887dF6fE905663CDB46c616BfBfBB50e85a265
- ConvexFallBack : https://etherscan.io/address/0x360CE1C08Ab93e940275149655CA8419e97f8b4c#code

## Curve

https://lend.curve.fi/#/ethereum

- Vault : https://etherscan.io/address/0xcea18a8752bb7e7817f9ae7565328fe415c0f2ca#code
- Controller : https://etherscan.io/address/0xEdA215b7666936DEd834f76f3fBC6F323295110A#code
- AMM : https://etherscan.io/address/0xafca625321Df8D6A068bDD8F1585d489D2acF11b#code

- Gauge STAKE :

## Inner

- https://docs.google.com/spreadsheets/d/1NBay39-V_1s75x62JKiDrEd_1xAD6upsau8Zr8AgX0Q/edit?gid=2082479589#gid=2082479589

## Documentation

- https://Resources.curve.fi/lending/overview/

## Data

- https://dune.com/mrblock_tw/curve-llamalend
- https://defillama.com/protocol/curve-llamalend#information
- https://messari.io/project/curve-llamalend/protocols/curve-llamalend

## Erc-4626

- https://ethereum.org/fr/developers/docs/standards/tokens/erc-4626/

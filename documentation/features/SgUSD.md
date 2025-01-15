# SgUSD

Users can deposit their `tgUSD` into the associated **Saving account** : `sgUSD`.

Staking `tgUSD` in `sgUSD` gives an **APY** to the user paid in tgUSD.
`SgUSD` is an ERC4626 deployed through **YearnFi Vaults V3**.

## Deposit

- Alice owns 1000 `tgUSD` and she wants to enjoys the 15% APY on `sgUSD`.
- She allows `sgUSD` to spend her `tgUSD`. ( **approve(sgUSDAddress,amount)** on `sgUSD` to spend `tgUSD` )
- She inputs 1000 `tgUSD`.
    - A call is made to `sgUSD` to return the amount of sgUSD minted in return ( **previewDeposit(tgUSDAmount)** ).
- She deposits `tgUSD` on `sgUSD` and she received `sgUSD`. ( **deposit(tgUSDAmount,userAddress)** on `sgUSD` )

## Withdraw

- Alice owns 1000 `sgUSD` from staking tgUSD.
- She inputs 1000 `sgUSD`.
    - A call is made to `sgUSD` to return the amount of sgUSD minted in return ( **previewRedeem(sgUSDAmount)** ).
- She withdraws `tgUSD` and get her `sgUSD` burnt. ( **deposit(tgUSDAmount,userAddress, userAddress)** on `sgUSD` )

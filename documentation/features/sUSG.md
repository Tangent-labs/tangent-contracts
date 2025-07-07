# sUSG

Users can deposit their `USG` into the associated **Saving account** : `sUSG`.

Staking `USG` in `sUSG` gives an **APY** to the user paid in USG.
`sUSG` is an ERC4626 deployed through **YearnFi Vaults V3**.

## Screen Loading

Chainview used to get global infos of the page is **sUSGUI** and is called with :

- [`userAddress`, `USGOracleAddress`, `USGAddress`, `sUSGAddress`]
- Returned object is on this format:
  ```
  struct sUSGUIOut {
      uint256 USGPrice;
      uint256 USGSupply;
      uint256 sUSGPrice;
      uint256 sUSGSupply;
      uint256 USGPercentageInsUSG;
      uint256 USGBalance;
      uint256 sUSGBalance;
      uint256 USGAllowance;
      }
  ```

## Deposit

- Alice owns 1000 `USG` and she wants to enjoys the 15% APY on `sUSG`.
- She allows `sUSG` to spend her `USG`. ( **approve(sUSGAddress,amount)** on `USG` )
- She inputs 1000 `USG`.
  - A call is made to `sUSG` to return the amount of sUSG minted in return ( **previewDeposit(USGAmount)** ).
- She deposits `USG` on `sUSG` and she received `sUSG`. ( **deposit(USGAmount, userAddress)** on `sUSG` )

## Withdraw

- Alice owns 1000 `sUSG` from staking USG.
- She inputs 1000 `sUSG`.
  - A call is made to `sUSG` to return the amount of sUSG minted in return ( **previewRedeem(sUSGAmount)** ).
- She withdraws `USG` and get her `sUSG` burnt. ( **redeem(USGAmount, userAddress, userAddress)** on `sUSG` )

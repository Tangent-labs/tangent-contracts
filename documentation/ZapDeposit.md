# ZapDeposit

Borrowers need to deposit the collateral token linked to the market.

However, `ZapDeposit` feature allows you don't have directly the collateral in you wallet to borrow on the market.
Our contract will swap the erc20 selected for the underlying collateral thanks to `Enso Finance` infra service.
A correct slippage has to be well setup in order to don't get front run on the execution and get less collateral than expected.

Ex :

- Alice has a 2000 USDC in her wallet.
- Alice wants to use these 2000 USDC to deposit in the crvUSD-USDC Market.
- Alice uses the ZapDeposit feature with 2000 USDC in input.
- Tangent Zapper contract swap 2000 USDC for crvUSD-USDC LP that are sent to the market.
- Tangent Market contract update the collateral deposit of Alice.

# ZapRepay

Users have always to repay their debt in USG. However, `ZapRepay` feature allows you to repay your debt with any ERC20.
Our contract will swap the erc20 selected for USG thanks to `Enso Finance` infra service.
A correct slippage has to be well setup in order to don't get front run on the execution.

Ex :

- Alice has a 2000 USG debt on a Tangent Market.
- Alice has 1 ETH in her wallet. At the moment ETH worth 3 000$.
- Alice uses the ZapRepay feature with 1ETH in input.
- Tangent Zapper contract swap 1ETH for 2999 USG that are sent to Alice wallet.
- Tangent Market contract removes Alice debt and burns 2000 USG on Alice wallet.
- Alice still has 999 USG on her wallet.

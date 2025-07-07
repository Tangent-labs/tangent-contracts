## Context

We need a screen where users are able to **Buy** and **Sell** assets Tangent assets.

## ToDo

- Implement the Buy Page UI
- User can input the amount in IN or the target in OUT.
- Allows to have 2 modes
  - Buy
    - Input : List of all tokens from our big token list + Tokens of Tangent
    - Output : Tokens of Tangent
  - Sell
    - Input : Tokens of Tangent + Tokens of Tangent
    - Output : List of all tokens from our big token list

## Tokens linked to USG

| Name        | Description                       | Type           |
| ----------- | --------------------------------- | -------------- |
| USG         | Our stablecoin                    | Normal coin    |
| sUSG        | Saving account of USG             | Saving account |
| wcrvUSD     | Wrapped crvUSD, staked as sCrvUSD | wStable        |
| wfrxUSD     | Wrapped frxUSD, staked as sFrxUSD | wStable        |
| wUSDe       | Wrapped USDe, staked as sUSDe     | wStable        |
| wDOLA       | Wrapped DOLA, staked as sDOLA     | wStable        |
| wUSR        | Wrapped USR, staked as wstUSR     | wStable        |
| USG-USDC    | Curve Stable pool                 | LP             |
| USG-wCrvUSD | Curve Stable pool                 | LP             |
| USG-wFrxUSD | Curve Stable pool                 | LP             |
| USG-wUSDS   | Curve Stable pool                 | LP             |
| USG-wDOLA   | Curve Stable pool                 | LP             |
| USG-wUSR    | Curve Stable pool                 | LP             |

## Routing

| In                | Out     | Quote                                  | Approval                               | Swap                                                    |
| ----------------- | ------- | -------------------------------------- | -------------------------------------- | ------------------------------------------------------- |
| USG               | sUSG    | sUSG.convertToShares(USGAmount)        | USG.approve(sUSG,MAX_UINT)             | sUSG.deposit(USGAmount, walletAddress)                  |
| sUSG              | USG     | sUSG.convertToAssets(sUSGAmount)       | No need                                | sUSG.redeem( sUSGAmount, walletAddress, walletAddress ) |
| frxUSD            | wfrxUSD | 1:1                                    | frxUSD.approve(wfrxUSD, MAX_UINT)      | wfrxUSD.mint(walletAddress, frxUSDAmount, false)        |
| sfrxUSD           | wfrxUSD | sfrxUSD.convertToAssets(sfrxUSDAmount) | sfrxUSD.approve(wfrxUSD, MAX_UINT)     | wfrxUSD.mint( walletAddress, sfrxUSDAmount, true )      |
| wfrxUSD           | frxUSD  | 1:1                                    | No need                                | wfrxUSD.burn( walletAddress, wfrxUSDAmount, false)      |
| wfrxUSD           | sfrxUSD | sfrxUSD.convertToShares(wfrxUSDAmount) | No need                                | wfrxUSD.burn( walletAddress, wfrxUSDAmount, true )      |
| crvUSD            | wcrvUSD | 1:1                                    | crvUSD.approve(wcrvUSD, MAX_UINT)      | wcrvUSD.mint(walletAddress, crvUSDAmount, false)        |
| scrvUSD           | wcrvUSD | scrvUSD.convertToAssets(scrvUSDAmount) | scrvUSD.approve(wcrvUSD, MAX_UINT)     | wcrvUSD.mint( walletAddress, scrvUSDAmount, true )      |
| wcrvUSD           | crvUSD  | 1:1                                    | No need                                | wcrvUSD.burn( walletAddress, wcrvUSDAmount, false)      |
| wcrvUSD           | scrvUSD | scrvUSD.convertToShares(wcrvUSDAmount) | No need                                | wcrvUSD.burn( walletAddress, wcrvUSDAmount, true )      |
| USDe              | wUSDe   | 1:1                                    | USDe.approve(wUSDe, MAX_UINT)          | wUSDe.mint(walletAddress, USDeAmount, false)            |
| sUSDe             | wUSDe   | sUSDe.convertToAssets(sUSDeAmount)     | sUSDe.approve(wUSDe, MAX_UINT)         | wUSDe.mint( walletAddress, sUSDeAmount, true )          |
| wUSDe             | USDe    | 1:1                                    | No need                                | wUSDe.burn( walletAddress, wUSDeAmount, false)          |
| wUSDe             | sUSDe   | sUSDe.convertToShares(wUSDeAmount)     | No need                                | wUSDe.burn( walletAddress, wUSDeAmount, true )          |
| DOLA              | wDOLA   | 1:1                                    | DOLA.approve(wDOLA, MAX_UINT)          | wDOLA.mint(walletAddress, DOLAAmount, false)            |
| sDOLA             | wDOLA   | sDOLA.convertToAssets(sDOLAAmount)     | sDOLA.approve(wDOLA, MAX_UINT)         | wDOLA.mint( walletAddress, sDOLAAmount, true )          |
| wDOLA             | DOLA    | 1:1                                    | No need                                | wDOLA.burn( walletAddress, wDOLAAmount, false)          |
| wDOLA             | sDOLA   | sDOLA.convertToShares(wDOLAAmount)     | No need                                | wDOLA.burn( walletAddress, wDOLAAmount, true )          |
| USR               | wUSR    | 1:1                                    | USR.approve(wUSR, MAX_UINT)            | wUSR.mint(walletAddress, USRAmount, false)              |
| wstUSR            | wUSR    | wstUSR.convertToAssets(sUSRAmount)     | wstUSR.approve(wUSR, MAX_UINT)         | wUSR.mint( walletAddress, wstUSRAmount, true )          |
| wUSR              | USR     | 1:1                                    | No need                                | wUSR.burn( walletAddress, wUSRAmount, false)            |
| wUSR              | wstUSR  | wstUSR.convertToShares(wUSRAmount)     | No need                                | wUSR.burn( walletAddress, wUSRAmount, true )            |
| All others routes | /       | Quote with Enso                        | tokenIn.approve(Enso Router, MAX_UINT) | ensoRouter.call(data) ( with data the return from API)  |

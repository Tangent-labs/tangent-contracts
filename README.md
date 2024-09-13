# Convergence study on Llamalend ( for yield splitter prodcut)

## Install dependencies

```
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts OpenZeppelin/openzeppelin-contracts-upgradeable OpenZeppelin/openzeppelin-foundry-upgrades --no-git

```
## update foundry 

```
foundryup
```

## Tests Commands

for more info : https://book.getfoundry.sh/reference/forge/forge-test

```
forge test --match-contract  LendRewardSplitterTest  -vvv --fail-fast
forge test --match-test testWith -vvv --fail-fast
```

**-v** : for the `--verbosity` part you can use up to 5 v  from  `-v` to `-vvvvv` 
**--fail-fast** : stop running tests after the first failure.



## Concepts

Curve has a loan marketplace, providers of these markets are rewarded in two ways:

- Stacking loan interest
- A gauge is assigned to each loan market, and the inflation reward can be distributed to the supplier.

Convergence's YieldSplitter product makes it possible to socialize these rewards and concentrate them on just one of these types.

The user deposits an asset and chooses the type of reward they want.
There are two types of reward:

- gUSD: governance token, all tokens from the gauge mechanism
- scvUSD: stable token, the stacking part of the lending mechanism.

## System

The aggregation will use STAKE DAO strategies to get the onlyboost

so for the splitter, we have several options for depositing:

- take the DAO stake deposits
- take the curve deposits and deposit them on StakeDAO
- Take the lend asset and deposit them on curve &  stake DAO. 
- Take other asset ( stable & ETH ) convert them into lend asset and depositt the lendasset

## Conception

### Options

- 1 multi market splitter contract 
- 2 tokens  for a market.

### Features

- Deposit gUSD
- Withdraw gUSD

- Deposit scvUSD
- Withdraw scvUSD



## Method : deposit  
    The deposit method will allow you to deposit into the splitter contrat assets related to the market . 
    - lendAsset 
    - curve vault asset. 
    - Stake dao vault asset. 
    you will be able to decide with side of the splitter you choose , and finally  deposit into stake DAO wich cost a large amount of gas 
    will be socialized , so you can decide if you want to deposit into stake or not. 

### Parameters
- address **stakeDaoVault**: The address of the market.
- TOKEN_TYPE  **inType**: The type of token being deposited. Types :  `LendAsset`,`LendCurveAsset`,`LendStakeDaoAsset`.
- uint256 **amount**: The amount of the inType token to be deposited.
- bool **isStableReward**: Determines the type of reward: (true for stable reward (`scvUSD`), false for gauge reward (`gUSD`).)
- bool **doDeposit**: If true, you will deposit into stakeDao , incentiveRewards will be added to your deposit.

### Process
1. Transfers the specified inType tokens from the user to the contract.
2. process doDeposit parameters 
     We use the sociabilisation already implemented in stakeDaoValut contract , the `doDeposit` parameter is match with the `doEarn` parameter of stakeDaoDeposit
3. Depending on the inType, deposits the tokens into the corresponding vault:
    - For `LendAsset`, transfer the asset & deposits into curveLendVault then in stakeDaoLendVault.
    - For `LendCurveAsset` transfer the asset & deposits into stakeDaoLendVault.
    - For `LendStakeDaoAsset`transfer the asset.
4. Mints the corresponding reward tokens based on the isStableReward flag: 
    - `scvUSD` for stable rewards, minted for each share deposit.
    - `gUSD` for gov rewards,minted for each asset deposit.

| `tokenIn`             | `isStableReward` | `Token Minted` | `Amount`                                                                 |
|-----------------------|------------------|---------------------|-----------------------------------------------------------------------|
| `LendAsset`           | `true`           | `scvUSD`            | Minted with curveLendVault.convertToShares(amount)                                       |
| `LendAsset`           | `false`          | `gUSD`              | Minted 1:1.      |
| `LendCurveAsset`      | `true`           | `scvUSD`            | Minted 1:1.                                        |
| `LendCurveAsset`      | `false`          | `gUSD`              | Minted with curveLendVault.convertToAssets(amount).      |
| `LendStakeDaoAsset`   | `true`           | `scvUSD`            | Minted 1:1.                                         |
| `LendStakeDaoAsset`   | `false`          | `gUSD`              | Minted with curveLendVault.convertToAssets(amount).      |


## Method : depositWithAssetOrETh  

- TBD


## Method : withdraw 

The withdraw function allows a user to withdraw assets from the Convergence Splitter contract.

### parameters 

- address **stakeDaoVault**: The address of the market.
- TOKEN_TYPE **outType**: The type of token to withdraw.  types :`LendAsset`, `LendCurveAsset`, `LendStakeDaoAsset`
- uint256 **amount**: The amount of reward tokens (gUSD or scvUSD) to withdraw.
- bool **isStableReward**: Determines the type of reward being withdrawn:
true to withdraw stable rewards using scvUSD.
false to withdraw gauge rewards using gUSD.

### Process
1. Checks prerequisites, including the non-zero amount and sufficient balance.
2. Burns the corresponding reward tokens from the user's balance, we use the `isStableReward` parameters 
in order to determine wich asset to burn: `true -> scvUSD `,  `false -> gUSD `.
3. Processes the withdrawal based on the outType
    - Details of flow base on  `outTokenType ` parameter
        - For  `LendStakeDaoAsset `, transfers the stake share to the user.
        - For  `LendCurveAsset `, withdraws the share from the StakeDAO vault and transfers it to the user.
        - For  `LendAsset `, checks the maximum redeemable amount, withdraws the share from the StakeDAO redeems from curveLendVault, and then transfers the asset to the user.
    - Amount of flow : the amount of asset return to the user depends on the  `isStableReward` parameters : 
        - `true `: all the asset are sent back to the user, 
        - `false `: curveLendVault.convertToAssets part is sent to the user, the other part is kept on the stakeDao vault, and will be proceeseed in the processStableReward method.
 

## Method : processStableRewardsMarket

This method will stream the accumulated  stable rewards , to the scvUSD holders for one market.

### parameters 
- address **stakeDaoVault**: The address of the market.

### Process
1. Determines the amount to stream, from the balance of stakeDaoShare we remove 
    - The totalSupply of scvUSD
    - The curveLendVault.convertToAssets(totalSupply of gUSD).
2. The amount is withdrawn from stakeDAo and then redeem from curve    
3. We feed the stream process  with this amount. 

## Method : claimStableReward 

### parameters 
- address **account**: The address of account to claim.

### Process
1. We calculate the amount of rewards for this account
2. We update the alreadyPaid variables  
3. We transfer the money to the account.  

# Deposit

Transfers an amount of crvUSD on the contract of tgUSD.
Mints the same amount of tgUSD in exchange.

**Should we wait for the next rebalancing to deposit these crvUSD in the Llamalend markets ?**

**Should we take into account the utilization rate of the markets ? If yes, what is the % limit ?**

# Withdraw

Burns the tgUSD of the user in exchange of some crvUSD that are on the tgUSD contract. If not enough tgUSD, we need to withdraw it from a contract of the LendSplitter.

**How to pick this or these contracts ? Should we pick the contracts with the smallest APR ?**

# Reward claiming / Indexation

Claims all rewards from cvUSD.
Claims all rewards from gUSD and dump them for crvUSD.
On the Vault pattern ERC4626, update the index of stgUSD.

# Rebalancing

1. Forks the last block of the mainnet
2. Withdraw all positions of tgUSD leading to have `N` crvUSD.
3. Computes APR on all scvUSD & gUSD.
4. Deposit `M` crvUSD on the highest APR, increment a mapping scvUSD/gUSD address with the `M` crvUSD.
5. Recomputes APR on the contract the deposit has been done
6. Repeat step 4 & 5 untill all `N` crvUSD has been distributed.
7. Computes the delta on each scvUSD/gUSD.
8. Deposit or withdraw the delta in crvUSD on each scvUSD/gUSD.

**Should we take into account the utilization rate of the vault during rebalancing?**

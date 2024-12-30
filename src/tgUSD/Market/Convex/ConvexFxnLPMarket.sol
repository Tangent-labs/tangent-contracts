// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ICvxFxnBooster} from "../../../interfaces/externals/Convex/ICvxFxnBooster.sol";
import {IStakingProxyERC20} from "../../../interfaces/externals/Convex/IStakingProxyERC20.sol";

import "../abstract/Rewards.sol";

import "forge-std/console.sol";

/// @notice Lending Market of a FXN LP on Convex
contract ConvexFxnLPMarket is Rewards {
    ICvxFxnBooster constant CVX_BOOSTER = ICvxFxnBooster(0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8);
    IStakingProxyERC20 public stakingProxyVault;

    constructor(
        address _owner,
        MarketInit memory _marketInit,
        IRewardAccumulator _rewardAccumulator,
        IERC20Metadata[] memory _rewardTokens,
        uint256 _pid
    ) Rewards(_owner, _marketInit, _rewardAccumulator, _rewardTokens) {
        address vaultAddress = CVX_BOOSTER.createVault(_pid);

        stakingProxyVault = IStakingProxyERC20(vaultAddress);

        // Need this approval to the llamaLendVault on the CvxBooster
        collatToken.approve(vaultAddress, MAX_UINT);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal override updateReward(_for) returns (uint256, IERC20) {
        // Verify collat amount added > 0
        require(lpDeposited != 0, ZeroCollatAmount());
        return (_sociabilizationProcess(lpDeposited, isStaked, DENOMINATOR), collatToken);
    }

    function _postDeposit(IERC20 _collatToken, uint256 lpStaked, bool isStaked) internal override {
        totalCollateral += lpStaked;
        if (isStaked) {
            stakingProxyVault.deposit(_collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

        // Verify that all there are enough LlamaLend LP on the contract
        if (lpAvailable < lpToWithdraw) {
            // If not enough are on the contract, we need to withdraw the difference from Convex
            stakingProxyVault.withdraw(lpToWithdraw - lpAvailable);
        }
        // Transfer the collateral back to the user
        collatToken.transfer(to, lpToWithdraw);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processRewards(address harvestFeeReceiver) external override {
        // Claim rewards of Convex FXN market
        stakingProxyVault.getReward();

        // Stream rewards to stakers and give rewards to harvester
        _processRewards(harvestFeeReceiver);
    }
}

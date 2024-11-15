// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ICvxFxnBooster} from "../../../interfaces/externals/Convex/ICvxFxnBooster.sol";
import {IStakingProxyERC20} from "../../../interfaces/externals/Convex/IStakingProxyERC20.sol";

import "../MarketRewards.sol";

import "forge-std/console.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract ConvexFxnLPMarket is MarketRewards {
    ICvxFxnBooster constant CVX_BOOSTER = ICvxFxnBooster(0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8);
    IStakingProxyERC20 public stakingProxyVault;

    constructor(
        MarketInit memory _marketInit,
        IRewardAccumulator _rewardAccumulator,
        IERC20[] memory _rewardTokens,
        uint256 _pid
    ) MarketRewards(_marketInit, _rewardAccumulator, _rewardTokens) {
        address vaultAddress = CVX_BOOSTER.createVault(_pid);

        stakingProxyVault = IStakingProxyERC20(vaultAddress);

        /// @dev Need this approval to the llamaLendVault on the CvxBooster
        collatToken.approve(vaultAddress, MAX_UINT);
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal override {
        if (isStaked) {
            stakingProxyVault.deposit(_collatToken.balanceOf(address(this)), true);
        }
    }

    function _postWithdraw(uint256 lpToWithdraw) internal override {
        uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

        /// @dev Verify that all there are enough LlamaLend LP on the contract
        if (lpAvailable < lpToWithdraw) {
            /// @dev If not enough are on the contract, we need to withdraw the difference from Convex
            stakingProxyVault.withdraw(lpToWithdraw - lpAvailable);
        }

        collatToken.transfer(msg.sender, lpToWithdraw);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processRewards(address harvestFeeReceiver) external override {
        /// @dev Claim rewards on behalf
        stakingProxyVault.getReward();
        _processRewards(harvestFeeReceiver);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";

import "../MarketRewards.sol";

import "forge-std/console.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract ConvexCrvLPMarket is MarketRewards {
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    ICvxRewardToken public cvxRewardToken;
    uint256 public pid;

    constructor(
        MarketInit memory _marketInit,
        IRewardAccumulator _rewardAccumulator,
        IERC20[] memory _rewardTokens,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid
    ) MarketRewards(_marketInit, _rewardAccumulator, _rewardTokens) {
        /// @dev Need this approval to the llamaLendVault on the CvxBooster
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);

        cvxRewardToken = _cvxRewardToken;
        pid = _pid;

        socFeePercentage = 1_000;
    }

    function _transferCollateralDeposit(IERC20 _collatToken, uint256 lpDeposited, uint256 lpStaked, bool isStaked) internal override {
        totalCollateral += lpStaked;
        _collatToken.transferFrom(msg.sender, address(this), lpDeposited);

        if (isStaked) {
            CVX_BOOSTER.deposit(pid, _collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

        /// @dev Verify that all there are enough LlamaLend LP on the contract
        if (lpAvailable < lpToWithdraw) {
            /// @dev If not enough are on the contract, we need to withdraw the difference from Convex
            cvxRewardToken.withdrawAndUnwrap(lpToWithdraw - lpAvailable, false);
        }

        collatToken.transfer(to, lpToWithdraw);
    }
    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processRewards(address harvestFeeReceiver) external override {
        /// @dev Claim rewards on behalf
        cvxRewardToken.getReward();
        _processRewards(harvestFeeReceiver);
    }
}

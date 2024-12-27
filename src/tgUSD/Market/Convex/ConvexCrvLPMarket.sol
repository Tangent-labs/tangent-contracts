// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";

import "../abstract/Rewards.sol";

import "forge-std/console.sol";

/// @notice Lending Market of a Curve LP on Convex
contract ConvexCrvLPMarket is Rewards {
    /// @notice Booster contract of Convex Curve. Used for depositing assets into pools.
    ICvxBooster public constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

    constructor(
        address _owner,
        MarketInit memory _marketInit,
        IRewardAccumulator _rewardAccumulator,
        IERC20Metadata[] memory _rewardTokens,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid
    ) Rewards(_owner, _marketInit, _rewardAccumulator, _rewardTokens) {
        // Allows CVX_BOOSTER to transfer LP from the market contract
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);

        cvxRewardToken = _cvxRewardToken;
        pid = _pid;
        socFeePercentage = 1_000;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal override updateReward(_for) returns (uint256, IERC20) {
        return (_sociabilizationProcess(lpDeposited, isStaked, DENOMINATOR), collatToken);
    }

    function _postDeposit(IERC20 _collatToken, uint256 lpStaked, bool isStaked) internal override {
        totalCollateral += lpStaked;
        if (isStaked) {
            CVX_BOOSTER.deposit(pid, _collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

        // Verify that all there are enough LlamaLend LP on the contract
        if (lpAvailable < lpToWithdraw) {
            // If not enough are on the contract, we need to withdraw the difference from Convex
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
        // Claim rewards on behalf
        cvxRewardToken.getReward();
        _processRewards(harvestFeeReceiver);
    }
}

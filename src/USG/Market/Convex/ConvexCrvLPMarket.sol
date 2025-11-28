// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";
import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/USG/IMarketCore.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @notice Lending Market of a Curve LP on Convex
contract ConvexCrvLPMarket is MarketExternalActions {
    /// @notice Booster contract of Convex Curve. Used for depositing assets into pools.
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Convex Crv
        // Allows CVX_BOOSTER to transfer LP from the market contract
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);
        // Dynamically retrieve the CvxRewardToken from the Booster with poolId
        (, , , address rewardToken, , ) = CVX_BOOSTER.poolInfo(_pid);
        require(address(0) != rewardToken);
        cvxRewardToken = ICvxRewardToken(rewardToken);
        pid = _pid;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _postDeposit(IERC20 _collatToken, bool isReceiptIn) internal override {
        CVX_BOOSTER.deposit(pid, _collatToken.balanceOf(address(this)), true);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw, bool isReceiptOut) internal override {
        // If not enough are on the contract, we need to withdraw the difference from Convex
        cvxRewardToken.withdrawAndUnwrap(lpToWithdraw, false);

        collatToken.transfer(to, lpToWithdraw);
    }

    /**

     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external override nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());
        // Claim rewards on the market
        cvxRewardToken.getReward();

        return _claimUnderlyingRewards(_rewardTokens);
    }
}

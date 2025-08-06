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
    ICvxBooster public constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

    error MarketNotLinkedToConvex();
    error CvxRewardTokenNull();
    error PidNull();

    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, ICvxRewardToken _cvxRewardToken, uint256 _pid) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Convex Crv
        // Allows CVX_BOOSTER to transfer LP from the market contract
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);

        if (address(_cvxRewardToken) != address(0)) {
            cvxRewardToken = _cvxRewardToken;
            pid = _pid;
        }
    }

    function setConvexStaking(ICvxRewardToken _cvxRewardToken, uint256 _pid) external onlyOwner {
        require(address(_cvxRewardToken) != address(0), CvxRewardTokenNull());
        require(_pid != 0, PidNull());
        pid = _pid;
        cvxRewardToken = _cvxRewardToken;
        // Stakes everything into Convex
        CVX_BOOSTER.deposit(_pid, collatToken.balanceOf(address(this)), true);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _postDeposit(IERC20 _collatToken) internal override {
        uint256 _pid = pid;

        // When pid = 0 / Means the Market is not yet linked to Convex
        if (_pid != 0) {
            CVX_BOOSTER.deposit(_pid, _collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        ICvxRewardToken _cvxRewardToken = cvxRewardToken;

        // If the LP is linked to Convex
        if (address(_cvxRewardToken) != address(0)) {
            // If not enough are on the contract, we need to withdraw the difference from Convex
            _cvxRewardToken.withdrawAndUnwrap(lpToWithdraw, false);
        }

        collatToken.transfer(to, lpToWithdraw);
    }

    /**

     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external override nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());

        ICvxRewardToken _cvxRewardToken = cvxRewardToken;

        if (address(_cvxRewardToken) != address(0)) {
            // Claim rewards on behalf
            _cvxRewardToken.getReward();
        }

        return _claimUnderlyingRewards(_rewardTokens);
    }
}

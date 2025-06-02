// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";
import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {Sociabilization} from "../../Utilities/Sociabilization.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @notice Lending Market of a Curve LP on Convex
contract ConvexCrvLPMarket is MarketExternalActions, Sociabilization {
    /// @notice Booster contract of Convex Curve. Used for depositing assets into pools.
    ICvxBooster public constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

    error MarketNotLinkedToConvex();

    function initialize(
        GlobalMarketInitParams memory _marketConstants,
        MarketInit memory _marketInit,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid,
        uint256 _socFeePercentage
    ) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Sociabilization
        _initializeSociabilization(_socFeePercentage);

        if (address(_cvxRewardToken) != address(0)) {
            // Convex Crv
            // Allows CVX_BOOSTER to transfer LP from the market contract
            collatToken.approve(address(CVX_BOOSTER), MAX_UINT);
            cvxRewardToken = _cvxRewardToken;
            pid = _pid;
        }
    }

    function setConvexStaking(ICvxRewardToken _cvxRewardToken, uint256 _pid) external onlyOwner {
        require(address(_cvxRewardToken) != address(0));
        require(_pid != 0);
        pid = _pid;
        cvxRewardToken = _cvxRewardToken;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _depositSociabilization(uint256 lpDeposited, bool isStaked) internal override returns (uint256) {
        uint256 stakedAmount = lpDeposited;
        require(lpDeposited != 0, ZeroCollatAmount());
        // When there are no Convex contract because no inflation yet
        if (pid != 0) {
            stakedAmount = _sociabilizationProcess(lpDeposited, isStaked, DENOMINATOR);
        }

        return stakedAmount;
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal override {
        uint256 _pid = pid;

        // When pid = 0 / Means the Market is not yet linked to Convex
        if (isStaked && _pid != 0) {
            CVX_BOOSTER.deposit(_pid, _collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        ICvxRewardToken _cvxRewardToken = cvxRewardToken;

        // If the LP is linked to Convex
        if (address(_cvxRewardToken) != address(0)) {
            uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

            // Verify that all there are enough LlamaLend LP on the contract
            if (lpAvailable < lpToWithdraw) {
                // If not enough are on the contract, we need to withdraw the difference from Convex
                _cvxRewardToken.withdrawAndUnwrap(lpToWithdraw - lpAvailable, false);
            }
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
            cvxRewardToken.getReward();
        }

        return _claimUnderlyingRewards(_rewardTokens);
    }

    //TODO Seems strange to me, enters maybe in collision with sociabilization pending fees.
    function stakeAll(address receiver) external nonReentrant {
        uint256 amountToStake = _stakeAll(receiver, collatToken);
        CVX_BOOSTER.deposit(pid, amountToStake, true);
    }
}

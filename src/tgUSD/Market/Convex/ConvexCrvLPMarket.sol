// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";
import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {Sociabilization} from "../../Utilities/Sociabilization.sol";
import "forge-std/console.sol";

/// @notice Lending Market of a Curve LP on Convex
contract ConvexCrvLPMarket is MarketExternalActions, Sociabilization {
    /// @notice Booster contract of Convex Curve. Used for depositing assets into pools.
    ICvxBooster public constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

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
        require(_socFeePercentage <= 2_000, SocFeeTooHigh());
        socFeePercentage = _socFeePercentage;

        // Convex Crv
        // Allows CVX_BOOSTER to transfer LP from the market contract
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);
        cvxRewardToken = _cvxRewardToken;
        pid = _pid;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal override updateReward(_for) returns (uint256, IERC20) {
        // Verify collat amount added > 0
        require(lpDeposited != 0, ZeroCollatAmount());
        return (_sociabilizationProcess(lpDeposited, isStaked, DENOMINATOR), collatToken);
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal override {
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
    function processRewards(address harvestFeeReceiver) external override updateReward(address(0)) {
        // Claim rewards on behalf
        cvxRewardToken.getReward();
        _processRewards(harvestFeeReceiver);
    }

    //TODO Seems strange to me, enters maybe in collision with sociabilization pending fees.
    function stakeAll(address receiver) external {
        IERC20 _collatToken = collatToken;
        _collatToken.transfer(receiver, socFeePending);
        CVX_BOOSTER.deposit(pid, _collatToken.balanceOf(address(this)), true);
    }
}

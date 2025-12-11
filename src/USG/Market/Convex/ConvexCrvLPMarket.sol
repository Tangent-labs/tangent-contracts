// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";
import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/USG/IMarketCore.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @title ConvexCrvLPMarket
/// @author Tangent Finance
/// @notice USG lending market with a Curve LP staked on Convex as collateral
contract ConvexCrvLPMarket is MarketExternalActions {
    /// @notice Booster contract of Convex Curve. Used for depositing assets into pools.
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    /// @notice Reward token of the corresponding Curve LP staked on Convex
    ICvxRewardToken public cvxRewardToken;

    /// @notice Id of the Curve pool on Convex
    uint256 public pid;

    error WrongPoolId();

    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Convex Crv
        // Allows CVX_BOOSTER to transfer LP from the market contract
        collatToken.approve(address(CVX_BOOSTER), MAX_UINT);
        // Dynamically retrieve the CvxRewardToken from the Booster with poolId
        // Don't need to check if rewardToken is null because `poolInfo(uint)` throws and error if the pid is incorrect
        (address lpToken, , , address rewardToken, , ) = CVX_BOOSTER.poolInfo(_pid);
        // Verify that the lpToken linked to the pid is the same as the collatToken
        require(lpToken == address(_marketInit.collatToken), WrongPoolId());
        cvxRewardToken = ICvxRewardToken(rewardToken);
        pid = _pid;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _postDeposit(IERC20 _collatToken) internal override {
        uint256 collatBalance = _collatToken.balanceOf(address(this));
        if (collatBalance != 0) {
            CVX_BOOSTER.deposit(pid, collatBalance, true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw, bool isReceiptOut) internal override {
        // Withdraw LP from convex to the market
        cvxRewardToken.withdrawAndUnwrap(lpToWithdraw, false);
        // Transfer the LP from the market to the receiver
        collatToken.transfer(to, lpToWithdraw);
    }

    function _claimRewards() internal override {
        // Claim rewards on the market
        cvxRewardToken.getReward();
    }
}

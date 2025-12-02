// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/USG/IMarketCore.sol";
import {IGauge} from "../../../interfaces/externals/Curve/IGauge.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @title  CurveGaugeMarket
/// @author Tangent Finance
/// @notice Lending Market of a Curve Gauge of a Curve LP. Used when there is no reward to boost throuh StakeDao or Convex.
contract CurveGaugeMarket is MarketExternalActions {
    address public receiptToken;

    error WrongGaugeToken();
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, address _gauge) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
        require(IGauge(_gauge).lp_token() == address(collatToken), WrongGaugeToken());

        collatToken.approve(address(_gauge), MAX_UINT);
        receiptToken = _gauge;
    }

    function _transferCollateralDeposit(uint256 collatToDeposit, bool isReceipt) internal override {
        if (isReceipt) {
            // Transfer the gauge token from the user to the market
            IGauge(receiptToken).transferFrom(msg.sender, address(this), collatToDeposit);
        } else {
            // Transfer the LP token from the user to the market
            collatToken.transferFrom(msg.sender, address(this), collatToDeposit);
        }
    }

    function _postDeposit(IERC20 _collatToken, bool isReceiptIn) internal override {
        if (!isReceiptIn) {
            // Deposit the whole balance of LP into the curve gauge
            IGauge(receiptToken).deposit(_collatToken.balanceOf(address(this)));
        }
    }

    function _transferCollateralWithdraw(address to, uint256 collatToWithdraw, bool isReceipt) internal override {
        if (isReceipt) {
            IGauge(receiptToken).transfer(to, collatToWithdraw);
        } else {
            // Withdraw the LP from the gauge to the market
            IGauge(receiptToken).withdraw(collatToWithdraw);
            // Transfer the LP to the receiver
            collatToken.transfer(to, collatToWithdraw);
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _claimRewards() internal override {
        // Claim the rewards from the gauge
        IGauge(receiptToken).claim_rewards();
    }
}

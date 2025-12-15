// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/USG/IMarketCore.sol";
import {IGauge} from "../../../interfaces/externals/Curve/IGauge.sol";
import {ICrvMinter} from "../../../interfaces/externals/Curve/ICrvMinter.sol";
import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @title  CurveGaugeMarket
/// @author Tangent Finance
/// @notice Lending Market of a Curve Gauge of a Curve LP. Used when there is no reward to boost throuh StakeDao or Convex.
contract CurveGaugeMarket is MarketExternalActions {
    address public receiptToken;
    ICrvMinter constant crvMinter = ICrvMinter(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);

    error WrongGaugeToken();
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, address _gauge) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
        require(IGauge(_gauge).lp_token() == address(collatToken), WrongGaugeToken());

        collatToken.approve(address(_gauge), MAX_UINT);
        receiptToken = _gauge;
    }

    function _transferCollateralDeposit(uint256 collatToDeposit, bool isReceiptIn) internal override {
        // Map the right token to transfer
        IERC20 _tokenIn = isReceiptIn ? IERC20(receiptToken) : collatToken;
        // Transfer the token from the caller to the market
        _tokenIn.transferFrom(msg.sender, address(this), collatToDeposit);
    }

    function _postDeposit(IERC20 _collatToken) internal override {
        uint256 collatBalance = _collatToken.balanceOf(address(this));
        if (collatBalance != 0) {
            // Deposit the whole balance of LP into the curve gauge
            IGauge(receiptToken).deposit(collatBalance);
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

    /**
     * @notice Claim CRV from the gauge in case it's needed in the future.
     *         As this type of market is designed for LP with no APR in CRV ( or very low ). It's very unlikely this will be used.
     */
    function claimCRV() external nonReentrant {
        crvMinter.mint(receiptToken);
    }
}

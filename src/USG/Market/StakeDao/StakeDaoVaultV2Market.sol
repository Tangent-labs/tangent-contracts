// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {GlobalMarketInitParams, MarketInit} from "../../../interfaces/internals/USG/IMarketCore.sol";
import {IStakeDaoVaultV2} from "../../../interfaces/externals/StakeDao/IStakeDaoVaultV2.sol";
import {IAccountant} from "../../../interfaces/externals/StakeDao/IAccountant.sol";

import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

/// @title  StakeDaoVaultV2Market
/// @author Tangent Finance
/// @notice Lending Market of a StakeDao Vault boosting CRV rewards of a Curve LP.
contract StakeDaoVaultV2Market is MarketExternalActions {
    address public receiptToken;
    IAccountant constant accountant = IAccountant(0x93b4B9bd266fFA8AF68e39EDFa8cFe2A62011Ce0);

    error WrongVaultToken();
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, address _receipt) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
        require(IStakeDaoVaultV2(_receipt).asset() == address(collatToken), WrongVaultToken());

        collatToken.approve(address(_receipt), MAX_UINT);
        receiptToken = _receipt;
    }

    function _transferCollateralDeposit(uint256 collatToDeposit, bool isReceiptIn) internal override {
        IERC20 _tokenIn = isReceiptIn ? IERC20(receiptToken) : collatToken;
        _tokenIn.transferFrom(msg.sender, address(this), collatToDeposit);
    }

    function _postDeposit(IERC20 _collatToken) internal override {
        uint256 collatBalance = _collatToken.balanceOf(address(this));
        if (collatBalance != 0) {
            // Deposit the whole balance of LP into the StakeDao Vault
            IStakeDaoVaultV2(receiptToken).deposit(collatBalance, address(this), controlTower.feeTreasury());
        }
    }

    function _transferCollateralWithdraw(address to, uint256 collatToWithdraw, bool isReceipt) internal override {
        if (isReceipt) {
            // Transfer the vault token to receiver
            IStakeDaoVaultV2(receiptToken).transfer(to, collatToWithdraw);
        } else {
            // Withdraw the LP from the Vault to the receiver
            IStakeDaoVaultV2(receiptToken).withdraw(collatToWithdraw, to, address(this));
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _claimRewards() internal override {
        address[] memory gauges = new address[](1);
        gauges[0] = address(IStakeDaoVaultV2(receiptToken).gauge());

        // When nothing is claimable, accountant.claim() revert
        // However, to be able to change reward cut, we want to be able to call processRewards at any moment.
        try accountant.claim(gauges, new bytes[](1)) {} catch {}
    }

    /**
     * @notice Claim the extra rewards from StakeDao Vault.
     *         Extra rewards can be CVX ( from OnlyBoost and Convex ) or any other rewards streamed in the vault
     */
    function claimExtraRewards(address[] calldata rewards) external nonReentrant {
        // Claim the extra rewards
        IStakeDaoVaultV2(receiptToken).claim(rewards, address(this));
    }
}

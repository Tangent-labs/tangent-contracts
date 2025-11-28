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
/// @notice Lending Market of a Curve Gauge of a Curve LP. Used when there is no reward to boost throuh StakeDao or Convex.
contract StakeDaoVaultV2Market is MarketExternalActions {
    IStakeDaoVaultV2 public vaultToken;
    IAccountant constant accountant = IAccountant(0x93b4B9bd266fFA8AF68e39EDFa8cFe2A62011Ce0);

    error WrongVaultToken();
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, IStakeDaoVaultV2 _vault) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
        require(_vault.asset() == address(collatToken), WrongVaultToken());

        collatToken.approve(address(_vault), MAX_UINT);
        vaultToken = _vault;
    }

    function _transferCollateralDeposit(uint256 collatToDeposit, bool isReceiptIn) internal override {
        IERC20 _tokenIn = isReceiptIn ? vaultToken : collatToken;
        _tokenIn.transferFrom(msg.sender, address(this), collatToDeposit);
    }

    function _postDeposit(IERC20 _collatToken, bool isReceiptIn) internal override {
        if (!isReceiptIn) {
            // Deposit the whole balance of LP StakeDao Vault
            vaultToken.deposit(_collatToken.balanceOf(address(this)), address(this));
        }
    }

    function _transferCollateralWithdraw(address to, uint256 collatToWithdraw, bool isReceipt) internal override {
        if (isReceipt) {
            // Transfer the vault token to receiver
            vaultToken.transfer(to, collatToWithdraw);
        } else {
            // Withdraw the LP from the Vault to the receiver
            vaultToken.withdraw(collatToWithdraw, to, address(this));
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**

     * @notice Claim and process the rewards from StakeDao
     * @dev Claim rewards from the corresponding StakeDao Vault SC and streams them for the stakers.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external override nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());

        address[] memory gauges = new address[](1);
        gauges[0] = address(vaultToken.gauge());

        // Harvest and claim CRV for the market
        try accountant.claim(gauges, new bytes[](1)) {} catch {}
        return _claimUnderlyingRewards(_rewardTokens);
    }

    /**
     * @notice Claim the extra rewards from StakeDao Vault.
     *         Extra rewards can be CVX ( from OnlyBoost and Convex ) or any other rewards streamed in the
     */
    function claimExtraRewards(IERC20[] calldata rewards) external {
        // Claim the extra rewards
        vaultToken.claim(rewards, address(this));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICvxFxnBooster} from "../../../interfaces/externals/Convex/ICvxFxnBooster.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IStakingProxyERC20} from "../../../interfaces/externals/Convex/IStakingProxyERC20.sol";
import {MarketInit, GlobalMarketInitParams} from "../../../interfaces/internals/USG/IMarketCore.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";
import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";

/// @title ConvexCrvLPMarket
/// @author Tangent Finance
/// @notice USG lending market with a Curve LP staked on Convex/FXN as collateral
contract ConvexFxnLPMarket is MarketExternalActions {
    ICvxFxnBooster constant CVX_BOOSTER = ICvxFxnBooster(0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8);
    IStakingProxyERC20 public stakingProxyVault;

    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Convex FXN
        address vaultAddress = CVX_BOOSTER.createVault(_pid);
        stakingProxyVault = IStakingProxyERC20(vaultAddress);
        // Need this approval to the llamaLendVault on the CvxBooster
        collatToken.approve(vaultAddress, MAX_UINT);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _postDeposit(IERC20 _collatToken) internal override {
        uint256 collatBalance = _collatToken.balanceOf(address(this));
        if (collatBalance != 0) {
            stakingProxyVault.deposit(collatBalance, true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw, bool isReceiptOut) internal override {
        // Withdraw from Convex vault
        stakingProxyVault.withdraw(lpToWithdraw);

        // Transfer the collateral back to the user
        collatToken.transfer(to, lpToWithdraw);
    }

    function _claimRewards() internal override {
        // Claim rewards of Convex FXN market
        stakingProxyVault.getReward();
    }
}

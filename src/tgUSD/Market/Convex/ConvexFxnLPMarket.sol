// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICvxFxnBooster} from "../../../interfaces/externals/Convex/ICvxFxnBooster.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IStakingProxyERC20} from "../../../interfaces/externals/Convex/IStakingProxyERC20.sol";
import {MarketInit, GlobalMarketInitParams} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";
import {MarketExternalActions} from "../abstract/MarketExternalActions.sol";
import {Sociabilization} from "../../Utilities/Sociabilization.sol";

/// @notice Lending Market of a FXN LP on Convex
contract ConvexFxnLPMarket is MarketExternalActions, Sociabilization {
    ICvxFxnBooster constant CVX_BOOSTER = ICvxFxnBooster(0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8);
    IStakingProxyERC20 public stakingProxyVault;

    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid, uint256 _socFeePercentage) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);

        // Sociabilization
        require(_socFeePercentage <= 2_000, SocFeeTooHigh());
        socFeePercentage = _socFeePercentage;

        // Convex FXN
        address vaultAddress = CVX_BOOSTER.createVault(_pid);
        stakingProxyVault = IStakingProxyERC20(vaultAddress);
        // Need this approval to the llamaLendVault on the CvxBooster
        collatToken.approve(vaultAddress, MAX_UINT);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal override updateRewards(_for) returns (uint256, IERC20) {
        // Verify collat amount added > 0
        require(lpDeposited != 0, ZeroCollatAmount());
        return (_sociabilizationProcess(lpDeposited, isStaked, DENOMINATOR), collatToken);
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal override {
        if (isStaked) {
            stakingProxyVault.deposit(_collatToken.balanceOf(address(this)), true);
        }
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        uint256 lpAvailable = collatToken.balanceOf(address(this)) - socFeePending;

        // Verify that all there are enough LlamaLend LP on the contract
        if (lpAvailable < lpToWithdraw) {
            // If not enough are on the contract, we need to withdraw the difference from Convex
            stakingProxyVault.withdraw(lpToWithdraw - lpAvailable);
        }
        // Transfer the collateral back to the user
        collatToken.transfer(to, lpToWithdraw);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external override updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());
        // Claim rewards of Convex FXN market
        stakingProxyVault.getReward();

        return _claimUnderlyingRewards(_rewardTokens);
    }

    //TODO Seems strange to me, enters maybe in collision with sociabilization pending fees.
    function stakeAll(address receiver) external {
        // Claim rewards on behalf
        IERC20 _collatToken = collatToken;
        _collatToken.transfer(receiver, socFeePending);
        stakingProxyVault.deposit(_collatToken.balanceOf(address(this)), true);
    }
}

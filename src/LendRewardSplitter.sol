// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveLendVault} from "./interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ISDLiquidityGauge} from "./interfaces/ISDLiquidityGauge.sol";
import {ICrvUSDController} from "./interfaces/ICrvUSDController.sol";
import {ICurveLendSplitterTokenStream} from "./interfaces/ICurveLendSplitterTokenStream.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "forge-std/console.sol"; //TODO: to remove

contract LendRewardSplitter is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICurveLendVault;
    using SafeERC20 for IStakeDaoVault;

    uint256 constant MAX_UINT = uint256(int256(-1));

    /// @dev Curve vault contract for lending (CurvelendVault).
    ICurveLendVault public curveLendVault;
    /// @dev Stake dao vault contract for lending (StakeDaoVault).
    IStakeDaoVault public stakeDaoVault;
    /// @dev collateral asset for lending (IERC20).
    IERC20 public lendAsset;

    /// @dev Issued for governance reward deposits(IERC20).
    ICurveLendSplitterTokenStream public gUSD;
    /// @dev Issued for stable reward deposits(IERC20).
    ICurveLendSplitterTokenStream public scvUSD;

    ISDLiquidityGauge public liquidityGauge;

    mapping(address => uint256) public balanceOf;

    mapping(IERC20 => uint256) public daoFeeForToken;

    event Deposit(address indexed account, bool isStableReward, uint256 amount);
    event Withdraw(address indexed account, bool isStableReward, TOKEN_TYPE outType, uint256 amount);

    enum TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev share of  curve vault contract. (ex : cvcrvUSD)
        LendCurveAsset,
        /// @dev share of  curve vault contract. (ex : sdcvcrvUSD)
        LendStakeDaoAsset
    }

    /**
     *  @notice initialize the contract.
     *  @param _curveLendVault Address of the lend market on curve.
     *  @param _stakeDaoVault Address of the  stakedao vault corresponding to the lend market on curve.
     *  @param _gUSD Address of  gUSD token created for this market.
     *  @param _scvUSD Address of scvUSD token created for this market.
     */
    function initialize(
        address _curveLendVault,
        address _stakeDaoVault,
        address _gUSD,
        address _scvUSD
    ) external initializer {
        /// @dev We initialize the lobal variables.
        curveLendVault = ICurveLendVault(_curveLendVault);
        stakeDaoVault = IStakeDaoVault(_stakeDaoVault);
        lendAsset = IERC20(curveLendVault.asset());

        gUSD = ICurveLendSplitterTokenStream(_gUSD);
        scvUSD = ICurveLendSplitterTokenStream(_scvUSD);

        /// @dev We approve the operation contract to move  tokens from/to this contract .
        lendAsset.approve(address(curveLendVault), MAX_UINT);
        curveLendVault.approve(address(stakeDaoVault), MAX_UINT);

        /// @dev We approve for the mint operation
        address _liquidityGauge = stakeDaoVault.liquidityGauge();
        liquidityGauge = ISDLiquidityGauge(_liquidityGauge);
        IERC20(_liquidityGauge).approve(_gUSD, MAX_UINT);
        IERC20(_liquidityGauge).approve(_scvUSD, MAX_UINT);

        /// @dev Set gUSD as the receiver of liquidity gauge rewards
        liquidityGauge.set_rewards_receiver(_gUSD);

        _transferOwnership(msg.sender);
    }

    /*
    TODO:
    deposit with...
    USDT/DAI/USDC/USDe/ETH/WETH
    */

    /**
     *  @notice Deposit asset into the Convergence splitter contract in order to get one part of the reawrd from the lend contract.
     *  @param inType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset >  LendStakeDaoAsset
     *  @param amount Amount  of {inType} token you want to deposit.
     *  @param isStableReward bool  IF isStableReward == true THEN   you want the stable part of the reward  ELSE you want the gauge part of the reward.
     *  @param doDeposit bool  IF doDeposit == true THEN  all the pending asset will be deposited in stakeValut.
     *  @return depositAmount Staked amount eligible to rewards.
     */
    function deposit(
        TOKEN_TYPE inType,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) external returns (uint256 depositAmount) {
        require(amount != 0, "NO_INPUT_AMOUNT");

        /// @dev Transfer the token from the user to this contract..
        _transferTokens(inType, amount);

        if (inType == TOKEN_TYPE.LendAsset) {
            /// @dev Deposit in curveLend.
            depositAmount = curveLendVault.deposit(amount, address(this));
        } else {
            /// @dev In others code path token are minted 1:1.
            depositAmount = amount;
        }

        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev Stake into stakedao strategies to get OnlyBoost.
            uint256 balanceBefore = IERC20(stakeDaoVault.liquidityGauge()).balanceOf(address(this));
            stakeDaoVault.deposit(address(this), depositAmount, doDeposit);
            uint256 balanceAfter = IERC20(stakeDaoVault.liquidityGauge()).balanceOf(address(this));
            depositAmount = balanceAfter - balanceBefore;
        }

        if (isStableReward) {
            /// @dev For scvUSD, we mint 1:1 from cvcrvUSD.
            scvUSD.mint(msg.sender, depositAmount);
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = curveLendVault.convertToAssets(depositAmount);
            gUSD.mint(msg.sender, depositAmount);
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdraw(TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");
        ICurveLendSplitterTokenStream recipeToken = isStableReward ? scvUSD : gUSD;
        require(amount <= recipeToken.balanceOf(msg.sender), "NOT_ENOUGH_BALANCE");

        /// @dev We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        /// @dev We process the amounts.
        uint256 shareAmount = isStableReward ? amount : curveLendVault.convertToShares(amount);

        if (outType == TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev we  transfer the stake share to the user.
            IERC20(stakeDaoVault.liquidityGauge()).safeTransfer(msg.sender, shareAmount);
        } else {
            /// @dev We withdraw the share from stakeDAO vault.
            stakeDaoVault.withdraw(shareAmount);
            // require(balanceBefore - balanceAfter >= shareAmount, "WITHDRAW ERROR");
            if (outType == TOKEN_TYPE.LendCurveAsset) {
                /// @dev we  transfer the stake share to the user.
                curveLendVault.safeTransfer(msg.sender, shareAmount);
            }
            if (outType == TOKEN_TYPE.LendAsset) {
                /// @dev We chack if we can withdraw from curvelend vault.
                uint256 maxShareAllowed = curveLendVault.maxRedeem(address(this));
                require(shareAmount <= maxShareAllowed, "MORE_THAN_MAX_WIDTHDRAW");
                /// @dev We withdraw from curvelend vault.
                uint256 assetAmountWithdrawn = curveLendVault.redeem(shareAmount);
                /// @dev We transfer to the user.
                lendAsset.safeTransfer(msg.sender, assetAmountWithdrawn);
            }
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _transferTokens(TOKEN_TYPE inType, uint256 amount) internal {
        /// @dev Transfer the token (LendAsset).
        if (inType == TOKEN_TYPE.LendAsset) {
            lendAsset.safeTransferFrom(msg.sender, address(this), amount);
        }

        /// @dev Transfer the token (LendCurveAsset) to this contract.
        if (inType == TOKEN_TYPE.LendCurveAsset) {
            IERC20(curveLendVault).safeTransferFrom(msg.sender, address(this), amount);
        }
        /// @dev Transfer the token (LendStakeDaoAsset) to this contract.
        if (inType == TOKEN_TYPE.LendStakeDaoAsset) {
            IERC20(stakeDaoVault.liquidityGauge()).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function stableDepositTotal() public view returns (uint256) {
        return scvUSD.totalSupply();
    }

    function govDepositTotal() public view returns (uint256) {
        return gUSD.totalSupply();
    }

    function stakeDaoVaultShareOwned() public view returns (uint256) {
        return IERC20(stakeDaoVault.liquidityGauge()).balanceOf(address(this));
    }

    //TODO: notice
    function updateDaoFees(IERC20[] memory tokens, uint256[] memory amounts) external {
        require(msg.sender == address(gUSD), "NOT_GUSD");
        require(tokens.length == amounts.length, "WRONG_LENGTH");
        for (uint256 i; i < tokens.length; ) {
            daoFeeForToken[tokens[i]] += amounts[i];
            unchecked {
                ++i;
            }
        }
    }

    //TODO: notice
    function approveGovReward(IERC20 token) external {
        require(msg.sender == address(gUSD), "NOT_GUSD");
        token.approve(msg.sender, MAX_UINT);
    }

    //TODO: notice
    function withdrawFees(IERC20[] memory tokens) external onlyOwner {
        //TODO: Change this function to send token to the right treasury
        for (uint256 i; i < tokens.length; ) {
            tokens[i].transfer(msg.sender, daoFeeForToken[tokens[i]]);
            delete daoFeeForToken[tokens[i]];
            unchecked {
                ++i;
            }
        }
    }
}

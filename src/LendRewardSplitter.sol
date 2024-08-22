// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveLendVault} from "./interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ISDLiquidityGauge} from "./interfaces/ISDLiquidityGauge.sol";
import {ICrvUSDController} from "./interfaces/ICrvUSDController.sol";
import {CurveLendSplitterTokenStream} from "./tokens/CurveLendSplitterTokenStream.sol";
import {ICurveLendSplitterTokenStream} from "./interfaces/ICurveLendSplitterTokenStream.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "forge-std/console.sol"; //TODO: to remove

contract LendRewardSplitter is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICurveLendVault;
    using SafeERC20 for IStakeDaoVault;

    uint256 constant MAX_UINT = uint256(int256(-1));

    mapping(IERC20 => uint256) public daoFeeForToken;
    mapping(address => MarketStruct) public markets;
    mapping(address => bool) public isSpecialUpdater;

    struct MarketStruct {
        ICurveLendVault curveLendVault;
        ISDLiquidityGauge liquidityGauge;
        IERC20 lendAsset;
        CurveLendSplitterTokenStream gUSD;
        CurveLendSplitterTokenStream scvUSD;
    }

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

    function initialize() external initializer {
        _transferOwnership(msg.sender);
    }

    function createMarket(IStakeDaoVault _stakeDaoVault) external onlyOwner {
        require(address(markets[address(_stakeDaoVault)].curveLendVault) == address(0), "MARKET_ALREADY_EXIST");
        ICurveLendVault _curveLendVault = ICurveLendVault(_stakeDaoVault.token());
        //TODO: require address(0)
        IERC20 _lendAsset = IERC20(_curveLendVault.asset());
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(_stakeDaoVault.liquidityGauge());
        //TODO:deploy gUSD via beacon
        CurveLendSplitterTokenStream _gUSD = new CurveLendSplitterTokenStream();
        _gUSD.initialize("Governance USD/CRV", "gUSD-CRV", address(this), address(_liquidityGauge));
        //TODO: deploy scvUSD via beacon
        CurveLendSplitterTokenStream _scvUSD = new CurveLendSplitterTokenStream();
        _scvUSD.initialize("Stable USD/CRV", "scvUSD-CRV", address(this), address(_liquidityGauge));

        /// @dev approvals
        _lendAsset.approve(address(_curveLendVault), MAX_UINT);
        _curveLendVault.approve(address(_stakeDaoVault), MAX_UINT);
        _liquidityGauge.approve(address(_gUSD), MAX_UINT);
        _liquidityGauge.approve(address(_scvUSD), MAX_UINT);

        _liquidityGauge.set_rewards_receiver(address(_gUSD));

        /// @dev save market on markets mapping
        markets[address(_stakeDaoVault)] = MarketStruct({
            curveLendVault: _curveLendVault,
            liquidityGauge: _liquidityGauge,
            lendAsset: _lendAsset,
            gUSD: _gUSD,
            scvUSD: _scvUSD
        });

        /// @dev WL gUSD as an special updater
        isSpecialUpdater[address(_gUSD)] = true;
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
        address stakeDaoVault,
        TOKEN_TYPE inType,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) external returns (uint256 depositAmount) {
        require(amount != 0, "NO_INPUT_AMOUNT");

        MarketStruct memory market = markets[stakeDaoVault];

        /// @dev Transfer the token from the user to this contract..
        _transferTokens(market, inType, amount);

        if (inType == TOKEN_TYPE.LendAsset) {
            /// @dev Deposit in curveLend.
            depositAmount = market.curveLendVault.deposit(amount, address(this));
        } else {
            /// @dev In others code path token are minted 1:1.
            depositAmount = amount;
        }

        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev Stake into stakedao strategies to get OnlyBoost.
            uint256 balanceBefore = market.liquidityGauge.balanceOf(address(this));
            IStakeDaoVault(stakeDaoVault).deposit(address(this), depositAmount, doDeposit);
            depositAmount = market.liquidityGauge.balanceOf(address(this)) - balanceBefore;
        }

        if (isStableReward) {
            /// @dev For scvUSD, we mint 1:1 from cvcrvUSD.
            market.scvUSD.mint(msg.sender, depositAmount);
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = market.curveLendVault.convertToAssets(depositAmount);
            market.gUSD.mint(msg.sender, depositAmount);
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdraw(address stakeDaoVault, TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");

        MarketStruct memory market = markets[stakeDaoVault];

        CurveLendSplitterTokenStream recipeToken = isStableReward ? market.scvUSD : market.gUSD;
        require(amount <= recipeToken.balanceOf(msg.sender), "NOT_ENOUGH_BALANCE");

        /// @dev We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        /// @dev We process the amounts.
        uint256 shareAmount = isStableReward ? amount : market.curveLendVault.convertToShares(amount);

        if (outType == TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev we  transfer the stake share to the user.
            IERC20(address(market.liquidityGauge)).safeTransfer(msg.sender, shareAmount);
        } else {
            /// @dev We withdraw the share from stakeDAO vault.
            IStakeDaoVault(stakeDaoVault).withdraw(shareAmount);
            // require(balanceBefore - balanceAfter >= shareAmount, "WITHDRAW ERROR");
            if (outType == TOKEN_TYPE.LendCurveAsset) {
                /// @dev we  transfer the stake share to the user.
                IERC20(address(market.curveLendVault)).safeTransfer(msg.sender, shareAmount);
            }
            if (outType == TOKEN_TYPE.LendAsset) {
                /// @dev We chack if we can withdraw from curvelend vault.
                uint256 maxShareAllowed = market.curveLendVault.maxRedeem(address(this));
                require(shareAmount <= maxShareAllowed, "MORE_THAN_MAX_WIDTHDRAW");
                /// @dev We withdraw from curvelend vault.
                uint256 assetAmountWithdrawn = market.curveLendVault.redeem(shareAmount);
                /// @dev We transfer to the user.
                IERC20(address(market.lendAsset)).safeTransfer(msg.sender, assetAmountWithdrawn);
            }
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _transferTokens(MarketStruct memory market, TOKEN_TYPE inType, uint256 amount) internal {
        /// @dev Transfer the token (LendAsset).
        if (inType == TOKEN_TYPE.LendAsset) {
            market.lendAsset.safeTransferFrom(msg.sender, address(this), amount);
        }

        /// @dev Transfer the token (LendCurveAsset) to this contract.
        if (inType == TOKEN_TYPE.LendCurveAsset) {
            market.curveLendVault.safeTransferFrom(msg.sender, address(this), amount);
        }
        /// @dev Transfer the token (LendStakeDaoAsset) to this contract.
        if (inType == TOKEN_TYPE.LendStakeDaoAsset) {
            IERC20(address(market.liquidityGauge)).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function stableDepositTotal(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].scvUSD.totalSupply();
    }

    function govDepositTotal(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].gUSD.totalSupply();
    }

    function stakeDaoVaultShareOwned(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].liquidityGauge.balanceOf(address(this));
    }

    function getMarket(address stakeDaoVault) external view returns (MarketStruct memory) {
        return markets[stakeDaoVault];
    }

    //TODO: notice
    function updateDaoFees(IERC20[] memory tokens, uint256[] memory amounts) external {
        require(isSpecialUpdater[msg.sender], "NOT_GUSD");
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
        require(isSpecialUpdater[msg.sender], "NOT_GUSD");
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ICurveLendVault} from "./interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ISDLiquidityGauge} from "./interfaces/ISDLiquidityGauge.sol";
import {ICrvUSDController} from "./interfaces/ICrvUSDController.sol";
import {ICurveLendSplitterTokenStream} from "./interfaces/ICurveLendSplitterTokenStream.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendRewardSplitter is Initializable {
    using SafeERC20 for IERC20;

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

    /// @dev Keep track of all deposit done for stable rewards.
    uint public stableDepositTotal;
    /// @dev Keep track of all deposit done for governance rewards.
    uint public govDepositTotal;

    mapping(address => uint) public balanceOf;

    event Deposit(address indexed account, bool isStableReward, uint256 amount);
    event Withdraw(
        address indexed account,
        bool isStableReward,
        TOKEN_TYPE outType,
        uint256 amount
    );

    enum TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev share of  curve vault contract. (ex : cvcrvUSD)
        LendCurveAsset,
        /// @dev share of  curve vault contract. (ex : sdcvcrvUSD)
        LendStakeDaoAsset
    }

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
    }
    function processRewards() external {
        processGovRewards();
    }
    function processGovRewards() internal {
        /// @dev Iterate through gauge rewards
        uint256 rewardCount = liquidityGauge.reward_count();
        IERC20[] memory rewardTokens = new IERC20[](rewardCount);
        uint256[] memory amountsClaim = new uint256[](rewardCount);
        /// @dev get balances before claim and addRewards if a new token has been added to the liquidity gauge
        for (uint256 i; i < rewardCount; ) {
            IERC20 rewardToken = IERC20(liquidityGauge.reward_tokens(i));
            rewardTokens[i] = rewardToken;
            ICurveLendSplitterTokenStream.Reward memory rewardData = gUSD
                .rewardData(rewardToken);
            /// @dev addReward if necessary
            if (rewardData.lastUpdateTime == 0) {
                gUSD.addReward(rewardToken);
            }
            amountsClaim[i] = rewardToken.balanceOf(address(gUSD));
            unchecked {
                ++i;
            }
        }
        /// @dev claim rewards
        liquidityGauge.claim_rewards(address(this), address(gUSD));

        /// @dev notify rewards for each rewardTokens
        bool isClaim = false;
        for (uint256 i; i < rewardTokens.length; ) {
            amountsClaim[i] =
                rewardTokens[i].balanceOf(address(gUSD)) -
                amountsClaim[i];
            if (amountsClaim[i] != 0) isClaim = true;
            unchecked {
                ++i;
            }
        }
        /// @dev if nothing to claim, continue to not ruin all the processes
        if (isClaim) gUSD.notifyRewards(rewardTokens, amountsClaim);
    }

    /*
    TODO:
    deposit with...
    USDT/DAI/USDC/USDe/ETH/WETH
    */

    /**
     *  @notice Deposit asset into the Convergence splitter contract in order to get one part of the reawrd from the lend contract.
     *  @param inType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset >  LendCurveGaugeAsset >  LendStakeDaoAsset
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
        _transferTokens(inType, amount, msg.sender);

        /// @dev Deposit in curveLend.
        if (inType == TOKEN_TYPE.LendAsset) {
            depositAmount = curveLendVault.deposit(amount, address(this)); //shareAmount
        }
        /// @dev In others code path token are minted 1:1.
        else {
            depositAmount = amount;
        }

        /// @dev Stake into stakedao strategies to get OnlyBoost.
        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            uint balanceBefore = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            stakeDaoVault.deposit(address(this), depositAmount, doDeposit);
            uint balanceAfter = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            depositAmount = balanceAfter - balanceBefore;
        }

        /// @dev Handle this contrat state.
        if (isStableReward) {
            scvUSD.mint(msg.sender, depositAmount);
            stableDepositTotal += depositAmount;
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD , we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = curveLendVault.convertToAssets(depositAmount);
            gUSD.mint(msg.sender, depositAmount);
            govDepositTotal += depositAmount;
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    function withdraw(
        TOKEN_TYPE outType,
        uint256 amount,
        bool isStableReward
    ) public {
        require(amount != 0, "WITHDRAW_LTE_0");

        ICurveLendSplitterTokenStream recipeToken = isStableReward
            ? scvUSD
            : gUSD;
        require(outType != TOKEN_TYPE.LendStakeDaoAsset, "OUT_TYPE_NOT_VALID");
        require(
            amount <= recipeToken.balanceOf(msg.sender),
            "NOT_ENOUGH_BALANCE"
        );

        /// @dev withdraw from stake DAO
        uint balanceBefore = curveLendVault.balanceOf(address(this));
        stakeDaoVault.withdraw(amount);
        uint balanceAfter = curveLendVault.balanceOf(address(this));
        uint amountWithdrawn = balanceAfter - balanceBefore;
        require(amountWithdrawn > 0, "NO_STAKEDAO_WITHDRAW");

        /// @dev we burn the corresponding token
        recipeToken.burn(msg.sender, amount);

        if (outType == TOKEN_TYPE.LendCurveAsset) {
            /// @dev we transfert the CURVE_VAULT_TOKEN to the user
            curveLendVault.transfer(msg.sender, amountWithdrawn);
        } else if (outType == TOKEN_TYPE.LendAsset) {
            /// @dev we withdraw from curve if needed
            uint maxWithdraw = curveLendVault.maxWithdraw(address(this));

            require(
                maxWithdraw < amountWithdrawn,
                "CANNOT_WIDTHDRAW_THIS_MUCH_FROM_CURVELEND"
            );
            uint crvUsdAmount = curveLendVault.withdraw(amountWithdrawn);
            lendAsset.transfer(msg.sender, crvUsdAmount);
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _transferTokens(
        TOKEN_TYPE inType,
        uint amount,
        address sender
    ) internal {
        /// @dev Transfer the token (LendAsset).
        if (inType == TOKEN_TYPE.LendAsset) {
            lendAsset.safeTransferFrom(sender, address(this), amount);
        }

        /// @dev Transfer the token (LendCurveAsset) to this contract.
        if (inType == TOKEN_TYPE.LendCurveAsset) {
            IERC20(curveLendVault).safeTransferFrom(
                sender,
                address(this),
                amount
            );
        }
        /// @dev Transfer the token (LendStakeDaoAsset) to this contract.
        if (inType == TOKEN_TYPE.LendStakeDaoAsset) {
            IERC20(stakeDaoVault.liquidityGauge()).safeTransferFrom(
                sender,
                address(this),
                amount
            );
        }
    }
}

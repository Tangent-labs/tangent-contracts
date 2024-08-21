import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ICurvelendVault} from "./interfaces/ICurvelendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ICrvUSDController} from "./interfaces/ICrvUSDController.sol";
import {ICurveLendSplitterToken} from "./interfaces/ICurveLendSplitterToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendRewardSplitter is Initializable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICurvelendVault;
    using SafeERC20 for IStakeDaoVault;

    // @dev Curve vault contract for lending (CurvelendVault).
    ICurvelendVault curveLendVault;
    // @dev Stake dao vault contract for lending (StakeDaoVault).
    IStakeDaoVault stakeDaoVault;
    // @dev collateral asset for lending (IERC20).
    IERC20 lendAsset;
    // @dev Issued for governance reward deposits(IERC20).
    ICurveLendSplitterToken gUsd;
    // @dev Issued for stable reward deposits(IERC20).
    ICurveLendSplitterToken svcUSD;

    uint256 MAX_INT = uint256(int256(-1));

    event Deposit(address indexed account, bool isStableReward, uint256 amount);

    event Withdraw(
        address indexed account,
        bool isStableReward,
        TOKEN_TYPE outType,
        uint256 amount
    );

    enum TOKEN_TYPE {
        // @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        // @dev share of  curve vault contract. (ex : cvcrvUSD)
        LendCurveAsset,
        // @dev share of  curve vault contract. (ex : sdcvcrvUSD)
        LendStakeDaoAsset
    }

    /**
     *  @notice initialize the contract.
     *  @param _curveLendVault Address of the lend market on curve.
     *  @param _stakeDaoVault Address of the  stakedao vault corresponding to the lend market on curve.
     *  @param _gUsd Address of  gUSD token created for this market.
     *  @param _svcUSD Address of svcUSD token created for this market.
     */
    function initialize(
        address _curveLendVault,
        address _stakeDaoVault,
        address _gUsd,
        address _svcUSD
    ) external initializer {
        // @dev We initialize the lobal variables.
        curveLendVault = ICurvelendVault(_curveLendVault);
        stakeDaoVault = IStakeDaoVault(_stakeDaoVault);
        lendAsset = IERC20(curveLendVault.asset());
        gUsd = ICurveLendSplitterToken(_gUsd);
        svcUSD = ICurveLendSplitterToken(_svcUSD);
        // @dev We approve the operation contract to move  tokens from/to this contract .
        lendAsset.approve(_curveLendVault, MAX_INT);
        curveLendVault.approve(_stakeDaoVault, MAX_INT);
    }

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
    ) public returns (uint256 depositAmount) {
        require(amount > 0, "NO_INPUT_AMOUNT");

        // @devs Transfer the token from the user to this contract..
        _transferTokens(inType, amount);

        if (inType == TOKEN_TYPE.LendAsset) {
            // @devs Deposit in curveLend.
            depositAmount = curveLendVault.deposit(amount, address(this));
        } else {
            // @devs In others code path token are minted 1:1.
            depositAmount = amount;
        }

        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            // @devs Stake into stakedao strategies to get OnlyBoost.
            uint256 balanceBefore = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            stakeDaoVault.deposit(address(this), depositAmount, doDeposit);
            uint256 balanceAfter = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            depositAmount = balanceAfter - balanceBefore;
        }

        if (isStableReward) {
            //@dev For svcUSD, we mint 1:1 from cvcrvUSD.
            svcUSD.mint(msg.sender, depositAmount);
        } else {
            //@dev For gUsd, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = curveLendVault.convertToAssets(depositAmount);
            gUsd.mint(msg.sender, depositAmount);
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSd|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUsd of user is used.
     */
    function withdraw(
        TOKEN_TYPE outType,
        uint256 amount,
        bool isStableReward
    ) public {
        // @devs We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");
        ICurveLendSplitterToken recipeToken = isStableReward ? svcUSD : gUsd;
        require(
            amount <= recipeToken.balanceOf(msg.sender),
            "NOT_ENOUGH_BALANCE"
        );

        // @devs We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        // @devs We process the amounts.
        uint256 shareAmount = isStableReward
            ? amount
            : curveLendVault.convertToShares(amount);

        if (outType == TOKEN_TYPE.LendStakeDaoAsset) {
            // @devs we  transfer the stake share to the user.
            IERC20(stakeDaoVault.liquidityGauge()).safeTransfer(
                msg.sender,
                shareAmount
            );
        } else {
            // @devs We withdraw the share from stakeDAO vault.
            stakeDaoVault.withdraw(shareAmount);
            // require(balanceBefore - balanceAfter >= shareAmount, "WITHDRAW ERROR");
            if (outType == TOKEN_TYPE.LendCurveAsset) {
                // @devs we  transfer the stake share to the user.
                curveLendVault.safeTransfer(msg.sender, shareAmount);
            }
            if (outType == TOKEN_TYPE.LendAsset) {
                /// @devs We chack if we can withdraw from curvelend vault.
                uint256 maxShareAllowed = curveLendVault.maxRedeem(
                    address(this)
                );
                require(
                    shareAmount <= maxShareAllowed,
                    "MORE_THAN_MAX_WIDTHDRAW"
                );
                /// @devs We withdraw from curvelend vault.
                uint256 assetAmountWithdrawn = curveLendVault.redeem(
                    shareAmount
                );
                /// @devs We transfer to the user.
                lendAsset.safeTransfer(msg.sender, assetAmountWithdrawn);
            }
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _transferTokens(TOKEN_TYPE inType, uint256 amount) internal {
        // @devs Transfer the token (LendAsset).
        if (inType == TOKEN_TYPE.LendAsset) {
            lendAsset.safeTransferFrom(msg.sender, address(this), amount);
        }

        // @devs Transfer the token (LendCurveAsset) to this contract.
        if (inType == TOKEN_TYPE.LendCurveAsset) {
            IERC20(curveLendVault).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
        // @devs Transfer the token (LendStakeDaoAsset) to this contract.
        if (inType == TOKEN_TYPE.LendStakeDaoAsset) {
            IERC20(stakeDaoVault.liquidityGauge()).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
    }

    function stableDepositTotal() public view returns (uint256) {
        return svcUSD.totalSupply();
    }

    function govDepositTotal() public view returns (uint256) {
        return gUsd.totalSupply();
    }

    function stakeDaoVaultShareOwned() public view returns (uint256) {
        return IERC20(stakeDaoVault.liquidityGauge()).balanceOf(address(this));
    }
}

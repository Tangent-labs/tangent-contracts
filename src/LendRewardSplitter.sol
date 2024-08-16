import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ICurvelendVault} from "./interfaces/ICurvelendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ICrvUSDController} from "./interfaces/ICrvUSDController.sol";
import {ICurveLendSplitterToken} from "./interfaces/ICurveLendSplitterToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendRewardSplitter is Initializable {
    using SafeERC20 for IERC20;

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

    // @dev Keep track of all deposit done for stable rewards.
    uint public stableDepositTotal;
    // @dev Keep track of all deposit done for governance rewards.
    uint public govDepositTotal;

    uint256 MAX_INT = uint256(int256(-1));

    mapping(address => uint) public balanceOf;

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
        lendAsset.approve(address(curveLendVault), MAX_INT);
        curveLendVault.approve(address(stakeDaoVault), MAX_INT);
        // @dev We approve for the mint operation
        IERC20(stakeDaoVault.liquidityGauge()).approve(_gUsd, MAX_INT);
        IERC20(stakeDaoVault.liquidityGauge()).approve(_svcUSD, MAX_INT);
    }

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
        uint amount,
        bool isStableReward,
        bool doDeposit
    ) public returns (uint depositAmount) {
        require(amount > 0, "NO_INPUT_AMOUNT");

        // @devs Transfer the token from the user to this contract..
        _transferTokens(inType, amount);

        // @devs Deposit in curveLend.
        if (inType == TOKEN_TYPE.LendAsset) {
            depositAmount = curveLendVault.deposit(amount, address(this));
        }
        // @devs In others code path token are minted 1:1.
        else {
            depositAmount = amount;
        }

        // @devs Stake into stakedao strategies to get OnlyBoost.
        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            uint balanceBefore = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            stakeDaoVault.deposit(address(this), depositAmount, doDeposit);
            uint balanceAfter = IERC20(stakeDaoVault.liquidityGauge())
                .balanceOf(address(this));
            depositAmount = balanceAfter - balanceBefore;
        }

       
        if (isStableReward) {
             //@dev For svcUSD, we mint 1:1 from cvcrvUSD.
            svcUSD.mint(msg.sender, depositAmount);
            stableDepositTotal += depositAmount;
        } else {
            //@dev For gUsd, we mint 1:1 from crvUSD , we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = curveLendVault.convertToAssets(depositAmount);
            gUsd.mint(msg.sender, depositAmount);
            govDepositTotal += depositAmount;
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    function withdraw(
        TOKEN_TYPE outType,
        uint amount,
        bool isStableReward
    ) public {
        require(amount != 0, "WITHDRAW_LTE_0");

        ICurveLendSplitterToken recipeToken = isStableReward ? svcUSD : gUsd;
        require(outType != TOKEN_TYPE.LendStakeDaoAsset, "OUT_TYPE_NOT_VALID");
        require(
            amount <= recipeToken.balanceOf(msg.sender),
            "NOT_ENOUGH_BALANCE"
        );

        // @devs withdraw from stake DAO
        uint balanceBefore = curveLendVault.balanceOf(address(this));
        stakeDaoVault.withdraw(amount);
        uint balanceAfter = curveLendVault.balanceOf(address(this));
        uint amountWithdrawn = balanceAfter - balanceBefore;
        require(amountWithdrawn > 0, "NO_STAKEDAO_WITHDRAW");

        // @devs we burn the corresponding token
        recipeToken.burn(msg.sender, amount);

        if (outType == TOKEN_TYPE.LendCurveAsset) {
            // @devs we transfert the CURVE_VAULT_TOKEN to the user
            curveLendVault.transfer(msg.sender, amountWithdrawn);
        } else if (outType == TOKEN_TYPE.LendAsset) {
            // @devs we withdraw from curve if needed
            uint maxWithdraw = curveLendVault.maxWithdraw(address(this));
            require(
                maxWithdraw < amountWithdrawn,
                "CANNOT_WIDTHDRAW_THIS_MUCH_FROM_CURVELEND"
            );
            uint amountAssetToWithdraw = curveLendVault.convertToAssets(
                amountWithdrawn
            );
            curveLendVault.withdraw(amountAssetToWithdraw);
            lendAsset.transfer(msg.sender, amountAssetToWithdraw);
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _transferTokens(TOKEN_TYPE inType, uint amount) internal {
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
}

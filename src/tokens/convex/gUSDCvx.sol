// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CurveLendSplitterToken.sol";
import {ICvxRewardToken} from "../../interfaces/externals/ICvxRewardToken.sol";
import {ICvxBooster} from "../../interfaces/externals/ICvxBooster.sol";
import {ILlamaLendVault} from "../../interfaces/externals/ILlamaLendVault.sol";
import {ILendRewardSplitter} from "../../interfaces/internals/ILendRewardSplitter.sol";

contract gUSDCvx is CurveLendSplitterToken {
    using SafeERC20 for IERC20;

    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    ICvxRewardToken public cvxRewardToken;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(
        string memory _name,
        string memory _symbol,
        ILendRewardSplitter _lendRewardSplitter,
        ICvxRewardToken _cvxRewardToken,
        IERC20 _llamaLendVault,
        IERC20 _cvxVault
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);

        lendRewardSplitter = _lendRewardSplitter;
        cvxRewardToken = _cvxRewardToken;

        /// @dev Need this approval to the llamaLendVault on the CvxBooster
        _llamaLendVault.approve(address(CVX_BOOSTER), MAX_UINT);

        /// @dev Need this approval to stake cvxVault assets on the corresponding CvxReward asset
        _cvxVault.approve(address(_cvxRewardToken), MAX_UINT);

        IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
        rewardTokens.push(crv);
        rewardData[crv].lastUpdateTime = uint128(block.timestamp);
        rewardData[crv].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));

        IERC20 cvx = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        rewardTokens.push(cvx);
        rewardData[cvx].lastUpdateTime = uint128(block.timestamp);
        rewardData[cvx].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function depositAndStake(ICvxRewardToken _cvxRewardToken, uint256 pid, uint256 depositAmount) external verifyLendSplitterCaller returns (uint256) {
        CVX_BOOSTER.deposit(pid, depositAmount, false);
        _cvxRewardToken.stakeAll();
        return depositAmount;
    }

    function depositNoStake(IERC20 _cvxVault, uint256 pid, uint256 depositAmount) external verifyLendSplitterCaller returns (uint256) {
        uint256 balanceBefore = _cvxVault.balanceOf(address(this));
        CVX_BOOSTER.deposit(pid, depositAmount, false);
        depositAmount = _cvxVault.balanceOf(address(this)) - balanceBefore;

        return depositAmount;
    }

    function withdraw(
        uint256 amount,
        address receiver,
        ILendRewardSplitter.CVX_TOKEN_TYPE outType,
        ILlamaLendVault llamaVault
    ) external verifyLendSplitterCaller {
        /// @dev We withdraw the Llamalend vault asset on this contract
        cvxRewardToken.withdrawAndUnwrap(amount, false);

        /// @dev The user claimed the LlamaLend vault asset so we transfer it to him directly
        if (outType == ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset) {
            llamaVault.transfer(receiver, amount);
        }
        /// @dev User claims the lent asset so we redeem it from the the LlamaLend vault
        else {
            llamaVault.redeem(amount, receiver);
        }
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processRewards() external {
        /// @dev Claim rewards on behalf
        cvxRewardToken.getReward();
        _processRewards();
    }
}

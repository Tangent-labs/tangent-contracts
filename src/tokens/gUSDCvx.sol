// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SplitterToken.sol";
import {ICvxRewardToken} from "../interfaces/externals/ICvxRewardToken.sol";
import {ICvxBooster} from "../interfaces/externals/ICvxBooster.sol";
import {ILlamaVault} from "../interfaces/externals/ILlamaVault.sol";
import {ILendRewardSplitter} from "../interfaces/internals/ILendRewardSplitter.sol";
import {IgUSDCvx} from "../interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../interfaces/internals/IscvUSD.sol";

contract gUSDCvx is SplitterToken, IgUSDCvx {
    using SafeERC20 for IERC20;

    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    ILlamaVault public llamaVault;

    ICvxRewardToken public cvxRewardToken;

    IscvUSD public scvUSD;

    IERC20 public cvxVault;

    uint256 public socFeePercentage;
    uint256 public socFeePending;

    error OnlySCVUSDCaller(address caller);
    error SocFeeTooHigh();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        ILendRewardSplitter _lendRewardSplitter,
        ICvxRewardToken _cvxRewardToken,
        ILlamaVault _llamaVault,
        IERC20 _cvxVault,
        IscvUSD _scvUSD
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(_owner);

        lendRewardSplitter = _lendRewardSplitter;
        cvxRewardToken = _cvxRewardToken;
        scvUSD = _scvUSD;
        cvxVault = _cvxVault;
        llamaVault = _llamaVault;

        /// @dev Need this approval to the llamaLendVault on the CvxBooster
        _llamaVault.approve(address(CVX_BOOSTER), MAX_UINT);

        /// @dev Need this approval to stake cvxVault assets on the corresponding CvxReward asset
        _cvxVault.approve(address(_cvxRewardToken), MAX_UINT);

        IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
        rewardTokens.push(crv);
        rewardData[crv].lastUpdateTime = uint128(block.timestamp);
        rewardData[crv].periodFinish = uint128(block.timestamp);
        fees.push(ISplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));

        IERC20 cvx = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        rewardTokens.push(cvx);
        rewardData[cvx].lastUpdateTime = uint128(block.timestamp);
        rewardData[cvx].periodFinish = uint128(block.timestamp);
        fees.push(ISplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));

        socFeePercentage = 1_000; // 1%
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function mint(address receiver, uint256 sharesAmount, ILlamaVault _llamaVault, uint256 pid, bool isStake) external returns (uint256) {
        sharesAmount = _sociabilizationProcess(sharesAmount, isStake);

        uint256 mintedAmount = _llamaVault.convertToAssets(sharesAmount);

        _mint(receiver, mintedAmount);

        if (isStake) {
            _stakeAll(pid);
        }
        return mintedAmount;
    }

    function _sociabilizationProcess(uint256 sharesAmount, bool isStake) internal returns (uint256) {
        if (isStake) {
            uint256 _socFeePending = socFeePending;
            sharesAmount += _socFeePending;
            delete socFeePending;
        } else {
            uint256 feeTaken = (sharesAmount * socFeePercentage) / DENOMINATOR;
            socFeePending += feeTaken;
            sharesAmount -= feeTaken;
        }
        return sharesAmount;
    }

    function sociabilizationAndStakeAll(uint256 sharesAmount, bool isStake, uint256 pid) public verifyLendSplitterCaller returns (uint256) {
        uint256 sharesAfterSociabilization = _sociabilizationProcess(sharesAmount, isStake);
        if (isStake) {
            _stakeAll(pid);
        }
        return sharesAfterSociabilization;
    }

    function stakeAll(uint256 pid) external {
        _stakeAll(pid);
    }

    function _stakeAll(uint256 pid) internal {
        CVX_BOOSTER.deposit(pid, llamaVault.balanceOf(address(this)) - socFeePending, true);
    }

    function burn(
        address from,
        uint256 amount,
        ILendRewardSplitter.CVX_TOKEN_TYPE outType,
        ILlamaVault _llamaVault
    ) external verifyLendSplitterCaller returns (uint256) {
        require(amount <= balanceOf(from), CantBurnThatMuchFor(from));

        _burn(from, amount);

        return _withdraw(_llamaVault.convertToShares(amount), from, outType, _llamaVault);
    }

    function withdraw(
        uint256 sharesToWithdraw,
        address receiver,
        ILendRewardSplitter.CVX_TOKEN_TYPE outType,
        ILlamaVault _llamaVault
    ) external verifyLendSplitterCaller returns (uint256) {
        return _withdraw(sharesToWithdraw, receiver, outType, _llamaVault);
    }

    function _withdraw(
        uint256 sharesToWithdraw,
        address receiver,
        ILendRewardSplitter.CVX_TOKEN_TYPE outType,
        ILlamaVault _llamaVault
    ) internal returns (uint256) {
        uint256 shareAvailable = _llamaVault.balanceOf(address(this)) - socFeePending;

        /// @dev Verify that all there are enough LlamaLend LP on the contract
        if (shareAvailable < sharesToWithdraw) {
            /// @dev If not enough are on the contract, we need to withdraw the difference from Convex
            cvxRewardToken.withdrawAndUnwrap(sharesToWithdraw - shareAvailable, false);
        }

        /// @dev The user claimed the LlamaLend vault asset so we transfer it to him directly
        if (outType == ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset) {
            _llamaVault.transfer(receiver, sharesToWithdraw);
            return sharesToWithdraw;
        }
        /// @dev User claims the lent asset so we redeem it from the the LlamaLend vault
        else {
            return _llamaVault.redeem(sharesToWithdraw, receiver);
        }
    }
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REWARD PROCESS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processGovRewards(address receiverProcessorRewards) external {
        /// @dev Claim rewards on behalf
        cvxRewardToken.getReward();
        _processRewards(receiverProcessorRewards);
    }

    function processStableRewards(address receiverProcessorRewards) external returns (uint256) {
        /// @dev Only scvUSD can call this function

        ICvxRewardToken _cvxRewardToken = cvxRewardToken;
        IscvUSD _scvUSD = scvUSD;
        ILlamaVault _llamaVault = llamaVault;

        uint256 totalSharesDeposited = _cvxRewardToken.balanceOf(address(this)) + _llamaVault.balanceOf(address(this));
        uint256 sharesToRemove = _scvUSD.totalSupply() + _llamaVault.convertToShares(totalSupply()) + socFeePending;

        uint256 sharesToClaim = totalSharesDeposited - sharesToRemove;
        uint256 sharesBalance = _llamaVault.balanceOf(address(this));

        if (sharesBalance < sharesToClaim) {
            _cvxRewardToken.withdrawAndUnwrap(sharesToClaim - sharesBalance, false);
        }

        _llamaVault.transfer(address(_scvUSD), sharesToClaim);
        scvUSD.processRewards(receiverProcessorRewards);
        return sharesToClaim;
    }

    function getTotalStaked() external view returns (uint256) {
        return cvxRewardToken.balanceOf(address(this)) + llamaVault.balanceOf(address(this));
    }

    function getStreamableShares() external view returns (uint256) {
        ILlamaVault _llamaVault = llamaVault;
        return
            cvxRewardToken.balanceOf(address(this)) +
            _llamaVault.balanceOf(address(this)) -
            scvUSD.totalSupply() -
            _llamaVault.convertToShares(totalSupply()) -
            socFeePending;
    }

    /**
     * @notice Sets the percetage of the sociabilization fee.
     * @param _socFee New sociabilization fee on a 100_000 basis
     */
    function setSociabilizationFee(uint256 _socFee) external {
        require(_socFee < 2_000, SocFeeTooHigh());
        /// @dev Claim rewards on behalf
        socFeePercentage = _socFee;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {IMarketRewards} from "../../interfaces/internals/tgUSD/IMarketRewards.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {Market, ItgUSD, IPriceOracle} from "./Market.sol";
import "forge-std/console.sol";
/// @notice Lending market
abstract contract MarketRewards is Market, IMarketRewards {
    using SafeERC20 for IERC20;
    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    /// @notice Percentage of reward of rewards to distribute to borrowers
    uint256 public rewardCutPercentage = 50_000;

    /// @notice Percentage of reward given to harvester on the rewards distributed to borrowers
    uint256 public harvesterFeePercentage;

    uint256 public totalCollateral;

    uint256 public socFeePercentage;
    uint256 public socFeePending;

    IRewardAccumulator public rewardAccumulator;

    /// @dev List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    struct Reward {
        uint128 lastUpdateTime;
        uint128 periodFinish;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);

    error HarvesterFeeToHigh();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);
    error SocFeeTooHigh();

    modifier updateReward(address _account) {
        _updateReward(_account);
        _;
    }
    constructor(MarketInit memory _marketInit, IRewardAccumulator _rewardAccumulator, IERC20[] memory _rewardTokens) Market(_marketInit) {
        rewardCutPercentage = 50_000;
        harvesterFeePercentage = 1_000;

        socFeePercentage = 1_000;

        rewardAccumulator = _rewardAccumulator;

        for (uint256 i; i < _rewardTokens.length; ) {
            IERC20 token = _rewardTokens[i];
            rewardTokens.push(token);
            rewardData[token].lastUpdateTime = uint128(block.timestamp);
            rewardData[token].periodFinish = uint128(block.timestamp);

            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSIT ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function deposit(address _for, uint256 lpDeposited, bool isStaked) external updateReward(_for) {
        (uint256 lpStaked, IERC20 _collatToken) = _preDeposit(lpDeposited, isStaked);
        require(lpStaked != 0);
        _deposit(_for, lpStaked);
        _postDeposit(_collatToken, isStaked);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 debtBorrow, bool isStaked) external updateReward(msg.sender) {
        (uint256 lpStaked, IERC20 _collatToken) = _preDeposit(lpDeposited, isStaked);
        require(lpStaked != 0);
        _depositAndBorrow(lpStaked, debtBorrow);
        _postDeposit(_collatToken, isStaked);
    }

    function depositAndRepay(address _for, uint256 lpDeposited, uint256 debtRepay, bool isStaked) external updateReward(_for) {
        (uint256 lpStaked, IERC20 _collatToken) = _preDeposit(lpDeposited, isStaked);
        require(lpStaked != 0);
        _depositAndRepay(_for, lpStaked, debtRepay);
        _postDeposit(_collatToken, isStaked);
    }
    function _preDeposit(uint256 lpDeposited, bool isStaked) internal returns (uint256, IERC20) {
        IERC20 _collatToken = collatToken;
        _collatToken.transferFrom(msg.sender, address(this), lpDeposited);
        lpDeposited = _sociabilizationProcess(lpDeposited, isStaked);
        totalCollateral += lpDeposited;

        return (lpDeposited, _collatToken);
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function withdraw(uint256 lpToWithdraw) external updateReward(address(0)) {
        _withdraw(lpToWithdraw);
        totalCollateral -= lpToWithdraw;
        _postWithdraw(lpToWithdraw);
    }

    function withdrawAndBorrow(uint256 lpToWithdraw, uint256 debtBorrow) external updateReward(address(0)) {
        _withdrawAndBorrow(lpToWithdraw, debtBorrow);
        totalCollateral -= lpToWithdraw;
        _postWithdraw(lpToWithdraw);
    }
    function withdrawAndRepay(uint256 lpToWithdraw, uint256 debtRepay) external updateReward(address(0)) {
        _withdrawAndRepay(lpToWithdraw, debtRepay);
        totalCollateral -= lpToWithdraw;
        _postWithdraw(lpToWithdraw);
    }

    function _postWithdraw(uint256 lpToWithdraw) internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        SOCIABILIZATION ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _sociabilizationProcess(uint256 lpDeposited, bool isStake) internal returns (uint256) {
        if (isStake) {
            lpDeposited += socFeePending;
            delete socFeePending;
        } else {
            uint256 feeTaken = (lpDeposited * socFeePercentage) / DENOMINATOR;
            socFeePending += feeTaken;
            lpDeposited -= feeTaken;
        }
        return lpDeposited;
    }

    /**
     * @notice Sets the percetage of the sociabilization fee.
     * @param _socFee New sociabilization fee on a 100_000 basis
     */
    function setSociabilizationFee(uint256 _socFee) external onlyOwner {
        require(_socFee < 2_000, SocFeeTooHigh());
        /// @dev Claim rewards on behalf
        socFeePercentage = _socFee;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Claim all pending rewards for an address
     * @dev Only lendRewardSplitter can call this function,
     *      returns a TokenAmount[] struct and the rewards receiver address
     * @param _address Address to claim rewards for
     */
    function getAndUpdateRewards(address _address) external updateReward(_address) returns (ICommonStruct.TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator));
        uint256 rewardTokensLength = rewardTokens.length;
        ICommonStruct.TokenAmount[] memory tokenAmounts = new ICommonStruct.TokenAmount[](rewardTokensLength);
        uint256 counter;
        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 _rewardToken = rewardTokens[tokenIndex];
            uint256 reward = rewards[_address][_rewardToken];

            if (reward > 0) {
                rewards[_address][_rewardToken] = 0;
                tokenAmounts[counter++] = ICommonStruct.TokenAmount({token: _rewardToken, amount: reward});
                emit RewardPaid(_address, _rewardToken, reward);
            }

            unchecked {
                ++tokenIndex;
            }
        }
        if (tokenAmounts.length != 0) {
            /// @dev Reduce length of tokenAmounts struct to not return useless 0

            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(tokenAmounts, sub(mload(tokenAmounts), sub(rewardTokensLength, counter)))
            }
        }

        return tokenAmounts;
    }
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Fetch the reward amount of a token based on the period
     * @param _rewardToken Address of the reward token
     * @return Total reward amount of the token
     */
    function _rewardPerToken(IERC20 _rewardToken) internal view returns (uint256) {
        if (totalCollateral == 0) {
            return rewardData[_rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) - rewardData[_rewardToken].lastUpdateTime) *
                rewardData[_rewardToken].rewardRate *
                1e18) / totalCollateral);
    }

    /**
     * @notice Fetch the amount earned
     * @param _user Address of the user
     * @param _rewardToken Address of the reward token
     * @param _balance Balance
     * @return Reward amount to claim for the user
     */
    function _earned(address _user, IERC20 _rewardToken, uint256 _balance) internal view returns (uint256) {
        return (_balance * (_rewardPerToken(_rewardToken) - userRewardPerTokenPaid[_user][_rewardToken])) / 1e18 + rewards[_user][_rewardToken];
    }

    function _lastTimeRewardApplicable(uint128 _finishTime) internal view returns (uint128) {
        return block.timestamp < _finishTime ? uint128(block.timestamp) : uint128(_finishTime);
    }

    /**
     * @notice Update reward data for every reward tokens for an address
     * @param _account Address of the user
     */
    function _updateReward(address _account) internal {
        uint256 userBal = collateralBalances[_account];

        uint256 rewardLength = rewardTokens.length;
        for (uint256 i; i < rewardLength; ) {
            IERC20 token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = _rewardPerToken(token);
            rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(rewardData[token].periodFinish);
            if (_account != address(0)) {
                rewards[_account][token] = _earned(_account, token, userBal);
                userRewardPerTokenPaid[_account][token] = rewardData[token].rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function processRewards(address harvestFeeReceiver) external virtual {}

    function _processRewards(address harvestFeeReceiver) internal {
        uint256 rewardCut = rewardCutPercentage;
        rewardCutPercentage = _calculateRewardCut(collatOracle.latestAnswer());
        /// @dev Reward tokens updated
        IERC20[] memory _rewardTokens = rewardTokens;
        uint256 rewardTokensLength = _rewardTokens.length;
        ICommonStruct.TokenAmount[] memory rewardCutToUpdate = new ICommonStruct.TokenAmount[](rewardTokensLength);

        bool isSomeRewardToProcess = false;
        uint256 _harvesterFeePercetage = harvesterFeePercentage;
        address _rewardAccumulator = address(rewardAccumulator);

        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 rewardToken = _rewardTokens[tokenIndex];
            uint256 rewardToProcess = rewardToken.balanceOf(address(this));

            if (rewardToProcess != 0) {
                isSomeRewardToProcess = true;

                /// @dev Calculate and sends harvester fees
                uint256 harvesterFees = (rewardToProcess * _harvesterFeePercetage) / DENOMINATOR;

                if (harvesterFees != 0) {
                    rewardToken.safeTransfer(harvestFeeReceiver, harvesterFees);
                }

                uint256 remainingRewards = rewardToProcess - harvesterFees;

                if (remainingRewards != 0) {
                    rewardToken.safeTransfer(_rewardAccumulator, remainingRewards);
                }
                uint256 rewardAmountCut = (remainingRewards * rewardCut) / DENOMINATOR;
                uint256 rewardAmountStreamed = remainingRewards - rewardAmountCut;

                /// @dev Reward Cut to update in
                rewardCutToUpdate[tokenIndex] = ICommonStruct.TokenAmount({token: rewardToken, amount: rewardAmountCut});

                require(rewardAmountStreamed > 1e10 && rewardAmountStreamed < 1e30, "INCORRECT_VALUE");

                Reward storage rData = rewardData[rewardToken];

                if (block.timestamp >= rData.periodFinish) {
                    rData.rewardRate = rewardAmountStreamed / REWARDS_DURATION;
                } else {
                    uint256 remaining = rData.periodFinish - block.timestamp;
                    uint256 leftover = remaining * rData.rewardRate;
                    rData.rewardRate = (rewardAmountStreamed + leftover) / REWARDS_DURATION;
                }

                rData.lastUpdateTime = uint128(block.timestamp);
                rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);

                emit RewardNotified(rewardToken, rewardAmountStreamed);
            }

            unchecked {
                ++tokenIndex;
            }
        }

        require(isSomeRewardToProcess, NothingToProcess());

        /// @dev Update Cut fees on the rewardAccumulator contract
        rewardAccumulator.incrementCutFees(rewardCutToUpdate);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function lastTimeRewardApplicable(IERC20 _rewardToken) external view returns (uint256) {
        return _lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish);
    }

    function rewardPerToken(IERC20 _rewardToken) external view returns (uint256) {
        return _rewardPerToken(_rewardToken);
    }

    function getRewardForDuration(IERC20 _rewardToken) external view returns (uint256) {
        return rewardData[_rewardToken].rewardRate * REWARDS_DURATION;
    }

    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardTokens;
    }
    function _calculateRewardCut(uint256 tgUSDPrice) internal pure returns (uint256) {
        /// @dev tgUSD >= 1$ / 50% of reward cut
        if (tgUSDPrice >= 1 ether) {
            return 50_000;
        }
        /// @dev 0.999875$ <= tgPrice < 1 / 60% of reward cut
        else if (tgUSDPrice >= 9987500000000000) {
            return 60_000;
        }
        /// @dev 0.9975$ <= tgPrice < 0.999875$ / 70% of reward cut
        else if (tgUSDPrice >= 997500000000000000) {
            return 70_000;
        }
        /// @dev 0.99625$ <= tgPrice < 0.9975$ / 80% of reward cut
        else if (tgUSDPrice >= 996250000000000000) {
            return 80_000;
        }
        /// @dev 0.995$ <= tgPrice < 0.99625$ / 90% of reward cut
        else if (tgUSDPrice >= 995000000000000000) {
            return 90_000;
        }
        /// @dev tgPrice < 0.995$ / 100% of reward cut
        else {
            return DENOMINATOR;
        }
    }
    /**
     * @notice Get the claimable amount of all reward tokens for the given address
     * @param _account Address of the user
     * @return userRewards Array of rewards
     */
    function claimableRewards(address _account) external view returns (ICommonStruct.TokenAmount[] memory userRewards) {
        userRewards = new ICommonStruct.TokenAmount[](rewardTokens.length);

        uint256 collateralBalance = collateralBalances[_account];
        for (uint256 erc20Id; erc20Id < userRewards.length; ) {
            IERC20 token = rewardTokens[erc20Id];
            userRewards[erc20Id].token = token;
            userRewards[erc20Id].amount = _earned(_account, token, collateralBalance);

            unchecked {
                ++erc20Id;
            }
        }

        return userRewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Set the percentage of rewards to be sent to the splitter as a DAO fees.
     * @param _newRewardToken rewards percentage value
     */
    function addNewReward(IERC20 _newRewardToken) external onlyOwner {
        /// @dev If lastUpdateTime is equal to 0, it means the token is not already added as a reward
        require(rewardData[_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

        rewardTokens.push(_newRewardToken);
        rewardData[_newRewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_newRewardToken].periodFinish = uint128(block.timestamp);
    }

    /**
     * @notice Set the percentage of rewards on the rewards streamed to borrowers to send to the processor.
     * @param _harvesterFeePercentage Percentage fee of the rewards streamed to borrowers.
     */
    function setHarvesterFeePercentage(uint256 _harvesterFeePercentage) external onlyOwner {
        require(_harvesterFeePercentage <= 2_000, HarvesterFeeToHigh());
        harvesterFeePercentage = _harvesterFeePercentage;
    }
}

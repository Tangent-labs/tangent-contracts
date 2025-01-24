// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICommonStruct} from "../../../interfaces/internals/ICommonStruct.sol";
import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {MarketExternalActions, MarketCore} from "./MarketExternalActions.sol";
import {Sociabilization} from "../../Utilities/Sociabilization.sol";
import "forge-std/console.sol";
/// @notice Lending market
abstract contract Rewards is MarketExternalActions, Sociabilization {
    using SafeERC20 for IERC20;
    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    /// @notice Percentage of reward of rewards to distribute to borrowers. 50_000 = 50%
    uint256 public rewardCutPercentage = 50_000;

    /// @notice Percentage of reward given to harvester. 1_000 = 1%
    uint256 public harvesterFeePercentage;

    /// @notice Receiver of all rewards produced by the market
    IRewardAccumulator public rewardAccumulator;

    /// @notice List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => IRewards.Reward) public rewardData; // token => reward data

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);

    error HarvesterFeeToHigh();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    modifier updateReward(address _account) {
        _updateReward(_account);
        _;
    }

    function _initializationCommon(MarketConstants memory _marketConstants, MarketInit memory _marketInit) internal {
        require(!isInitialized, AlreadyInitialized());
        isInitialized = true;
        // Rewards
        rewardCutPercentage = 50_000;
        harvesterFeePercentage = 1_000;

        // Rewards
        for (uint256 i; i < _marketInit._rewardTokens.length; ) {
            IERC20Metadata token = _marketInit._rewardTokens[i];
            rewardTokens.push(token);
            rewardData[token].lastUpdateTime = uint128(block.timestamp);
            rewardData[token].periodFinish = uint128(block.timestamp);

            unchecked {
                ++i;
            }
        }

        // Core
        tgUSD = _marketConstants._tgUSD;
        controlTower = _marketConstants._controlTower;
        irCalculator = _marketConstants._irCalculator;
        rewardAccumulator = _marketConstants._rewardAccumulator;
        liquidatorProxy = _marketConstants._liquidatorProxy;

        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        lastIR = 10 * RAY; // 10%
        blockLastIRTimestamp = block.timestamp;
        debtIndex = RAY;

        // Gives ownership to the DAO
        _transferOwnership(_marketConstants._owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW  
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preWithdraw(uint256 lpToWithdraw) internal override updateReward(address(0)) {
        totalCollateral -= lpToWithdraw;
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

        /// @dev Reduce length of tokenAmounts struct to not return useless 0
        if (tokenAmounts.length != 0) {
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
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) - rewardData[_rewardToken].lastUpdateTime) * rewardData[_rewardToken].rewardRate * 1e18) /
                totalCollateral);
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

        //  We compute the reward cut only if it's activated
        if (rewardCut != 0) {
            rewardCutPercentage = irCalculator.computeRCForMarket(address(this));
        }
        // Reward tokens updated
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

                // Calculate and sends harvester fees
                uint256 harvesterFees = (rewardToProcess * _harvesterFeePercetage) / DENOMINATOR;

                if (harvesterFees != 0) {
                    rewardToken.safeTransfer(harvestFeeReceiver, harvesterFees);
                }

                uint256 remainingRewards = rewardToProcess - harvesterFees;

                if (remainingRewards != 0) {
                    rewardToken.safeTransfer(_rewardAccumulator, remainingRewards);
                }

                uint256 rewardAmountStreamed;
                if (rewardCut != 0) {
                    uint256 rewardAmountCut = (remainingRewards * rewardCut) / DENOMINATOR;
                    rewardCutToUpdate[tokenIndex] = ICommonStruct.TokenAmount({token: rewardToken, amount: rewardAmountCut});
                    rewardAmountStreamed = remainingRewards - rewardAmountCut;
                } else {
                    rewardAmountStreamed = remainingRewards;
                }

                IRewards.Reward storage rData = rewardData[rewardToken];

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

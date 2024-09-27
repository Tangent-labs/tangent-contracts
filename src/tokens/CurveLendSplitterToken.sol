// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendRewardSplitter} from "../interfaces/internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../interfaces/internals/ICurveLendSplitterToken.sol";
import {ICommonStruct} from "../interfaces/internals/ICommonStruct.sol";

import {Errors} from "../libs/Errors.sol";

import "forge-std/console.sol"; //TODO: to remove

abstract contract CurveLendSplitterToken is ERC20Upgradeable, OwnableUpgradeable, ICurveLendSplitterToken {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT = uint256(int256(-1));

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    uint256 public constant DENOMINATOR = 100_000;

    ILendRewardSplitter public lendRewardSplitter;

    /// @notice Fee percentages
    ICurveLendSplitterToken.Fees[] public fees;

    /// @dev List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => ICurveLendSplitterToken.Reward) public rewardData; // token => reward data

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);

    error NotLendRewardSplitter(address _address);
    error WrongFeesPercetageLength(uint256 givenLength, uint256 rightLength);
    error CantWithdrawRewardToken(IERC20 erc20);
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        MODIFIERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    modifier updateReward(address _account) {
        _updateReward(_account);
        _;
    }

    modifier verifyLendSplitterCaller() {
        /// @dev Requires the lendRewardSplitter is the caller of this function
        require(msg.sender == address(lendRewardSplitter), NotLendRewardSplitter(msg.sender));
        _;
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
    function getAndUpdateRewards(address _address) external updateReward(_address) verifyLendSplitterCaller returns (ICommonStruct.TokenAmount[] memory) {
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
                    EXTERNAL LENDSPLITTER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Burn staked token
     * @param from        Owner of the staked ERC20 token
     * @param amount      Amount to burn
     */
    function burn(address from, uint256 amount) external virtual verifyLendSplitterCaller {
        require(amount <= balanceOf(from), "NOT_ENOUGH_BALANCE");
        /// @dev Burn will call _updateReward
        _burn(from, amount);
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
        if (totalSupply() == 0) {
            return rewardData[_rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) - rewardData[_rewardToken].lastUpdateTime) *
                rewardData[_rewardToken].rewardRate *
                1e18) / totalSupply());
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
        uint256 userBal = balanceOf(_account);

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

    function _processRewards() internal {
        /// @dev Reward tokens updated
        IERC20[] memory _rewardTokens = rewardTokens;
        uint256 rewardTokensLength = _rewardTokens.length;
        ICommonStruct.TokenAmount[] memory daoFeesToUpdate = new ICommonStruct.TokenAmount[](rewardTokensLength);

        bool isSomeRewardToProcess = false;

        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 rewardToken = _rewardTokens[tokenIndex];
            ICurveLendSplitterToken.Fees memory feePercentage = fees[tokenIndex];
            uint256 rewardToProcess = rewardToken.balanceOf(address(this));

            if (rewardToProcess != 0) {
                isSomeRewardToProcess = true;
                /// @dev Calculate fees
                uint256 processorFees = (rewardToProcess * feePercentage.processorFeePercentage) / DENOMINATOR;
                uint256 daoFees = (rewardToProcess * feePercentage.daoFeePercentage) / DENOMINATOR;

                /// @dev Send rewards to processor
                if (processorFees != 0) {
                    rewardToken.safeTransfer(msg.sender, processorFees);
                    rewardToProcess -= processorFees;
                }

                /// @dev Send reward to process + DAO fees to the splitter
                rewardToken.safeTransfer(address(lendRewardSplitter), rewardToProcess);

                /// @dev DAO fees update
                if (daoFees != 0) {
                    daoFeesToUpdate[tokenIndex] = ICommonStruct.TokenAmount({token: rewardToken, amount: daoFees});
                    rewardToProcess -= daoFees;
                }
                require(rewardToProcess > 1e10 && rewardToProcess < 1e30, "INCORRECT_VALUE");

                ICurveLendSplitterToken.Reward storage rData = rewardData[rewardToken];

                if (block.timestamp >= rData.periodFinish) {
                    rData.rewardRate = rewardToProcess / REWARDS_DURATION;
                } else {
                    uint256 remaining = rData.periodFinish - block.timestamp;
                    uint256 leftover = remaining * rData.rewardRate;
                    rData.rewardRate = (rewardToProcess + leftover) / REWARDS_DURATION;
                }

                rData.lastUpdateTime = uint128(block.timestamp);
                rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);

                emit RewardNotified(rewardToken, rewardToProcess);
            }

            unchecked {
                ++tokenIndex;
            }
        }

        require(isSomeRewardToProcess, NothingToProcess());

        /// @dev Update DAO fees on the splitter contract
        lendRewardSplitter.incrementDaoFees(daoFeesToUpdate);
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

        for (uint256 erc20Id; erc20Id < userRewards.length; ) {
            IERC20 token = rewardTokens[erc20Id];
            userRewards[erc20Id].token = token;
            userRewards[erc20Id].amount = _earned(_account, token, balanceOf(_account));

            unchecked {
                ++erc20Id;
            }
        }

        return userRewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       ERC20 OVERRIDE
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    // TODO Verify this behavior
    function _update(address from, address to, uint256 value) internal override {
        /// @dev do the checkpoint before the transfer
        if (from != address(0)) {
            _updateReward(from);
        }
        if (to != address(0)) {
            _updateReward(to);
        }
        super._update(from, to, value);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Set the percentage of rewards to be sent to the splitter as a DAO fees.
     * @param _newRewardToken rewards percentage value
     */
    function addNewReward(IERC20 _newRewardToken, ICurveLendSplitterToken.Fees calldata _newFees) external onlyOwner {
        /// @dev If lastUpdateTime is equal to 0, it means the token is not already added as a reward
        require(rewardData[_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

        rewardTokens.push(_newRewardToken);
        rewardData[_newRewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_newRewardToken].periodFinish = uint128(block.timestamp);
        fees.push(_newFees);
    }

    /**
     * @notice Set the percentage of rewards to be sent to the splitter as a DAO fees.
     * @param _newFees rewards percentage value
     */
    function setFees(ICurveLendSplitterToken.Fees[] calldata _newFees) external onlyOwner {
        uint256 newFeesLength = _newFees.length;
        require(newFeesLength == rewardTokens.length, WrongFeesPercetageLength(newFeesLength, rewardTokens.length));

        for (uint256 feeIndex; feeIndex < newFeesLength; ) {
            fees[feeIndex] = _newFees[feeIndex];
            unchecked {
                ++feeIndex;
            }
        }
    }

    /**
     * @notice Transfer ERC20 tokens on this contract to the caller address
     * @param _tokenAddress Address of the token
     * @param _tokenAmount Amount to transfer
     */
    function recoverToken(IERC20 _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(rewardData[_tokenAddress].lastUpdateTime == 0, CantWithdrawRewardToken(_tokenAddress));

        _tokenAddress.safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }
}

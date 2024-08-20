// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendRewardSplitter} from "../interfaces/ILendRewardSplitter.sol";
import {ISDLiquidityGauge} from "../interfaces/ISDLiquidityGauge.sol";
import "forge-std/console.sol";//TODO: to remove

contract CurveLendSplitterTokenStreamV2 is ERC20Upgradeable, OwnableUpgradeable {
    struct Reward {
        uint128 lastUpdateTime;
        uint128 periodFinish;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }
    struct EarnedData {
        IERC20 token;
        uint256 amount;
    }
    using SafeERC20 for IERC20;
    uint256 constant MAX_UINT = uint256(int256(-1));

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    uint256 private constant DENOMINATOR = 100_000;

    ILendRewardSplitter public lendRewardSplitter;

    /// @notice Percentage of rewards to be sent to the user who processed the GOV rewards
    uint256 public processorRewardsPercentage; //Question: same fee percentage for all tokens ?

    /// @notice Percentage of GOV rewards to be sent to the splitter and claimed by the DAO
    uint256 public daoFeesPercentage; //Question: same fee percentage for all tokens ?

    /// @dev List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @dev Reward redirection data
    mapping(address => address) public rewardRedirect; // owner => receiver

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);
    event RewardRedirected(address indexed _account, address _forward);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    /// @notice initialize function
    function initialize(string memory _name, string memory _symbol) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);
        processorRewardsPercentage = 1000; /// @dev TODO: TO CHANGE -> corresponds to 1%
        daoFeesPercentage = 2000; /// @dev TODO: TO CHANGE -> corresponds to 2%
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        MODIFIERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    modifier updateReward(address _account) {
        _updateReward(_account);
        _;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Set reward redirection address for the caller
     * @dev Set address to zero to disable
     * @param _to Address of the receiver
     */
    function setRewardRedirect(address _to) external {
        rewardRedirect[msg.sender] = _to;
        emit RewardRedirected(msg.sender, _to);
    }

    /**
     * @notice Claim all pending rewards for an address
     * @dev Anyone can call this function for any address
     * @param _address Address to claim rewards for
     */
    function getReward(address _address) external updateReward(_address) {
        for (uint256 i; i < rewardTokens.length; ) {
            IERC20 _rewardToken = rewardTokens[i];
            uint256 reward = rewards[_address][_rewardToken];

            if (reward > 0) {
                rewards[_address][_rewardToken] = 0;
                if (rewardRedirect[_address] != address(0)) {
                    _rewardToken.safeTransferFrom(address(lendRewardSplitter), rewardRedirect[_address], reward);
                } else {
                    _rewardToken.safeTransferFrom(address(lendRewardSplitter), _address, reward);
                }

                emit RewardPaid(_address, _rewardToken, reward);
            }

            unchecked {
                ++i;
            }
        }
    }

    //TODO: Notice
    function processGovRewards() external {
        /// @dev Claim rewards on behalf of the splitter on this contract
        //TODO: save liquidityGauge variable on this contract ?
        lendRewardSplitter.liquidityGauge().claim_rewards(address(lendRewardSplitter));

        /// @dev Update reward tokens if a new one have been added
        uint256 rewardTokensLength = rewardTokens.length;
        _updateRewardTokens(rewardTokensLength);

        /// @dev Reward tokens updated
        IERC20[] memory _rewardTokens = rewardTokens;
        rewardTokensLength = _rewardTokens.length;
        uint256[] memory daoFeesToUpdate = new uint256[](rewardTokensLength);

        bool isProcess = false;
        uint256 _daoFeesPercentage = daoFeesPercentage;
        uint256 _processorRewardsPercentage = processorRewardsPercentage;
        for (uint256 i; i < rewardTokensLength; ) {
            uint256 rewardToProcess = _rewardTokens[i].balanceOf(address(this));
            if (rewardToProcess != 0) {
                isProcess = true;
                /// @dev Calculate fees
                uint256 processorFees = (rewardToProcess * _processorRewardsPercentage) / DENOMINATOR;
                uint256 daoFees = (rewardToProcess * _daoFeesPercentage) / DENOMINATOR;

                /// @dev Send rewards to processor
                if (processorFees != 0) {
                    _rewardTokens[i].transfer(msg.sender, processorFees);
                    rewardToProcess -= processorFees;
                }

                /// @dev Send reward to process + DAO fees to the splitter
                _rewardTokens[i].transfer(address(lendRewardSplitter), rewardToProcess);

                /// @dev DAO fees update
                if (daoFees != 0) {
                    daoFeesToUpdate[i] = daoFees;
                    rewardToProcess -= daoFees;
                }

                /// @dev Notify rewards
                _notifyRewardAmount(_rewardTokens[i], rewardToProcess);
            }

            unchecked {
                ++i;
            }
        }
        /// @dev Revert if nothing to process
        require(isProcess, "NOTHING_TO_PROCESS");

        /// @dev Update DAO fees on the splitter contract
        lendRewardSplitter.updateDaoFees(_rewardTokens, daoFeesToUpdate);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       EXTERNAL DAO
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Mint Staked tokens
     * @param to        Receiver of the staked token ERC20
     * @param amount    Amount of staked token
     */
    function mint(address to, uint256 amount) external returns (uint256) {
        require(msg.sender == address(lendRewardSplitter), "NOT_LEND_REWARD_SPLITTER");

        /// @dev Requires that some tokens are deposited
        require(amount != 0, "AMOUNT_LTE");

        /// @dev Mint will call _updateReward
        _mint(to, amount);

        return amount;
    }

    /**
     * @notice Burn Underlying token
     * @param from        Owner of the staked token ERC20
     * @param amount      Amount to burn
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == address(lendRewardSplitter), "NOT_LEND_REWARD_SPLITTER");

        require(amount != 0, "AMOUNT_LTE");

        /// @dev Burn will call _updateReward
        _burn(from, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// @notice If a new token reward is added on the liquidity gauge, update it
    function _updateRewardTokens(uint256 currentRewardTokens) internal {
        ISDLiquidityGauge _liquidityGauge = lendRewardSplitter.liquidityGauge();
        uint256 rewardCount = _liquidityGauge.reward_count();
        for (uint256 i = currentRewardTokens; i < rewardCount; ) {
            IERC20 rewardToken = IERC20(_liquidityGauge.reward_tokens(i));
            _addReward(rewardToken);
            lendRewardSplitter.approveGovReward(rewardToken);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Add a new reward token to be distributed to users
     * @param _rewardToken Address of the reward token
     */
    function _addReward(IERC20 _rewardToken) internal {
        require(rewardData[_rewardToken].lastUpdateTime == 0, "REWARD_TOKEN_ALREADY_EXISTS");
        require(_rewardToken != IERC20(address(this)), "INVALID_TOKEN");

        rewardTokens.push(_rewardToken);
        rewardData[_rewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_rewardToken].periodFinish = uint128(block.timestamp);

        emit RewardAdded(_rewardToken);
    }

    /**
     * @notice Notify reward amount for a reward token
     * @param _rewardToken Address of the reward token
     * @param _reward Reward amount
     */
    function _notifyRewardAmount(IERC20 _rewardToken, uint256 _reward) internal updateReward(address(0)) {
        require(_reward > 0 && _reward < 1e30, "INCORRECT_VALUE");

        _notifyReward(_rewardToken, _reward);

        emit RewardNotified(_rewardToken, _reward);
    }

    /**
     * @notice Fetch the reward amount of a token based on the period
     * @param _rewardToken Address of the reward token
     * @return Total reward amount of the token
     */
    function _rewardPerToken(IERC20 _rewardToken) internal view returns (uint256) {
        if (totalSupply() == 0) return rewardData[_rewardToken].rewardPerTokenStored;

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) -
                rewardData[_rewardToken].lastUpdateTime) *
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
        return
            (_balance * (_rewardPerToken(_rewardToken) - userRewardPerTokenPaid[_user][_rewardToken])) /
            1e18 +
            rewards[_user][_rewardToken];
    }

    function _lastTimeRewardApplicable(uint128 _finishTime) internal view returns (uint128) {
        return block.timestamp < _finishTime ? uint128(block.timestamp) : uint128(_finishTime);
    }

    /**
     * @notice Update reward data for the specified reward token
     * @param _rewardToken Address of the reward token
     * @param _reward Reward amount
     */
    function _notifyReward(IERC20 _rewardToken, uint256 _reward) internal {
        Reward storage rData = rewardData[_rewardToken];

        if (block.timestamp >= rData.periodFinish) {
            rData.rewardRate = _reward / REWARDS_DURATION;
        } else {
            uint256 remaining = rData.periodFinish - block.timestamp;
            uint256 leftover = remaining * rData.rewardRate;
            rData.rewardRate = (_reward + leftover) / REWARDS_DURATION;
        }

        rData.lastUpdateTime = uint128(block.timestamp);
        rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);
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
    function claimableRewards(address _account) external view returns (EarnedData[] memory userRewards) {
        userRewards = new EarnedData[](rewardTokens.length);

        for (uint256 i; i < userRewards.length; ) {
            IERC20 token = rewardTokens[i];
            userRewards[i].token = token;
            userRewards[i].amount = _earned(_account, token, balanceOf(_account));

            unchecked {
                ++i;
            }
        }

        return userRewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       ERC20 OVERRIDE
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _update(address from, address to, uint256 value) internal override {
        //do the checkpoint before the transfer
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
     * @notice Set the percentage of rewards to be sent to the user processing the GOV rewards.
     * @param _percentage rewards percentage value
     */
    function setProcessorRewardsPercentage(uint256 _percentage) external onlyOwner {
        /// @dev it must never exceed 3% (TODO: ???)
        require(_percentage <= 3000, "PERCENTAGE_TOO_HIGH");
        processorRewardsPercentage = _percentage;
    }

    //TODO: notice
    function setDaoFeesPercentage(uint256 _percentage) external onlyOwner {
        /// @dev it must never exceed 3% (TODO: ???)
        require(_percentage <= 3000, "PERCENTAGE_TOO_HIGH");
        daoFeesPercentage = _percentage;
    }

    //TODO: remove for singleton
    function setLendRewardSplitter(address _lendRewardSplitter) external onlyOwner {
        lendRewardSplitter = ILendRewardSplitter(_lendRewardSplitter);
    }

    /**
     * @notice Transfer ERC20 tokens on this contract to the caller address
     * @param _tokenAddress Address of the token
     * @param _tokenAmount Amount to transfer
     */
    function recoverToken(IERC20 _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(rewardData[_tokenAddress].lastUpdateTime == 0, "CANNOT_WITHDRAW_REWARD_TOKEN");

        _tokenAddress.safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }
}

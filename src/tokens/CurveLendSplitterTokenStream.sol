// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CurveLendSplitterTokenStream is ERC20, Ownable {
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
    uint256 MAX_UINT = uint256(int256(-1));

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    address public lendRewardSplitter;

    /// @dev List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @dev Reward redirection data
    mapping(address => address) public rewardRedirect; // owner => receiver

    /// @dev Addresses approved to notify reward amount
    // mapping(IERC20 => mapping(address => bool)) public rewardDistributors; // reward token => distributor => is approved to add rewards

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256))
        public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(
        address indexed _user,
        IERC20 indexed _rewardToken,
        uint256 _reward
    );
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(
        IERC20 indexed _reward,
        address indexed _distributor,
        bool _state
    );
    event RewardRedirected(address indexed _account, address _forward);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {}

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
     * @notice Mint Staked tokens
     * @param to        Receiver of the staked token ERC20
     * @param amount    Amount of staked token
     */
    function mint(address to, uint256 amount) external returns (uint256) {
        require(msg.sender == lendRewardSplitter, "NOT_LEND_REWARD_SPLITTER");

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
        require(msg.sender == lendRewardSplitter, "NOT_LEND_REWARD_SPLITTER");

        require(amount != 0, "AMOUNT_LTE");

        /// @dev Burn will call _updateReward
        _burn(from, amount);
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
                    _rewardToken.safeTransfer(rewardRedirect[_address], reward);
                } else {
                    _rewardToken.safeTransfer(_address, reward);
                }

                emit RewardPaid(_address, _rewardToken, reward);
            }

            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    EXTERNALS DAO
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Add a new reward token to be distributed to users
     * @param _rewardToken Address of the reward token
     */
    function addReward(IERC20 _rewardToken) external {
        require(msg.sender == lendRewardSplitter, "NOT_LEND_REWARD_SPLITTER");
        require(
            rewardData[_rewardToken].lastUpdateTime == 0,
            "REWARD_TOKEN_ALREADY_EXISTS"
        );
        require(_rewardToken != IERC20(address(this)), "INVALID_TOKEN");

        rewardTokens.push(_rewardToken);
        rewardData[_rewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_rewardToken].periodFinish = uint128(block.timestamp);

        emit RewardAdded(_rewardToken);
    }

    function notifyRewards(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewards
    ) external {
        require(msg.sender == lendRewardSplitter, "NOT_LEND_REWARD_SPLITTER");
        //require length == length
        for (uint256 i; i < _rewardTokens.length; ) {
            if (_rewards[i] != 0)
                _notifyRewardAmount(_rewardTokens[i], _rewards[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Notify reward amount for a reward token
     * @param _rewardToken Address of the reward token
     * @param _reward Reward amount
     */
    function _notifyRewardAmount(
        IERC20 _rewardToken,
        uint256 _reward
    ) internal updateReward(address(0)) {
        require(_reward > 0 && _reward < 1e30, "INCORRECT_VALUE");

        _notifyReward(_rewardToken, _reward);

        // /// @dev Handle the transfer of reward tokens via `transferFrom` to reduce the number
        // /// @dev of transactions required and ensure correctness of the _reward amount
        // _rewardToken.safeTransferFrom(msg.sender, address(this), _reward);

        emit RewardNotified(_rewardToken, _reward);
    }

    /**
     * @notice Transfer ERC20 tokens on this contract to the treasury DAO address
     * @dev Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
     * @param _tokenAddress Address of the token
     * @param _tokenAmount Amount to transfer
     */
    function recoverToken(
        IERC20 _tokenAddress,
        uint256 _tokenAmount
    ) external onlyOwner {
        require(
            rewardData[_tokenAddress].lastUpdateTime == 0,
            "CANNOT_WITHDRAW_REWARD_TOKEN"
        );

        _tokenAddress.safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Fetch the reward amount of a token based on the period
     * @param _rewardToken Address of the reward token
     * @return Total reward amount of the token
     */
    function _rewardPerToken(
        IERC20 _rewardToken
    ) internal view returns (uint256) {
        if (totalSupply() == 0)
            return rewardData[_rewardToken].rewardPerTokenStored;

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(
                rewardData[_rewardToken].periodFinish
            ) - rewardData[_rewardToken].lastUpdateTime) *
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
    function _earned(
        address _user,
        IERC20 _rewardToken,
        uint256 _balance
    ) internal view returns (uint256) {
        return
            (_balance *
                (_rewardPerToken(_rewardToken) -
                    userRewardPerTokenPaid[_user][_rewardToken])) /
            1e18 +
            rewards[_user][_rewardToken];
    }

    function _lastTimeRewardApplicable(
        uint128 _finishTime
    ) internal view returns (uint128) {
        return
            block.timestamp < _finishTime
                ? uint128(block.timestamp)
                : uint128(_finishTime);
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
            rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(
                rewardData[token].periodFinish
            );

            if (_account != address(0)) {
                rewards[_account][token] = _earned(_account, token, userBal);
                userRewardPerTokenPaid[_account][token] = rewardData[token]
                    .rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }

    function lastTimeRewardApplicable(
        IERC20 _rewardToken
    ) external view returns (uint256) {
        return _lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish);
    }

    function rewardPerToken(
        IERC20 _rewardToken
    ) external view returns (uint256) {
        return _rewardPerToken(_rewardToken);
    }

    function getRewardForDuration(
        IERC20 _rewardToken
    ) external view returns (uint256) {
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
    function claimableRewards(
        address _account
    ) external view returns (EarnedData[] memory userRewards) {
        userRewards = new EarnedData[](rewardTokens.length);

        for (uint256 i; i < userRewards.length; ) {
            IERC20 token = rewardTokens[i];
            userRewards[i].token = token;
            userRewards[i].amount = _earned(
                _account,
                token,
                balanceOf(_account)
            );

            unchecked {
                ++i;
            }
        }

        return userRewards;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        //do the checkpoint before the transfer
        if (from != address(0)) {
            _updateReward(from);
        }
        if (to != address(0)) {
            _updateReward(to);
        }
        super._update(from, to, value);
    }

    function setLendRewardSplitter(
        address _lendRewardSplitter
    ) external onlyOwner {
        lendRewardSplitter = _lendRewardSplitter;
    }
}

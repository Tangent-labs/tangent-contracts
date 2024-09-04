// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendRewardSplitter} from "../interfaces/ILendRewardSplitter.sol";
import {ISDLiquidityGauge} from "../interfaces/ISDLiquidityGauge.sol";
import {ICurveLendVault} from "../interfaces/ICurveLendVault.sol";

contract CurveLendSplitterToken is ERC20Upgradeable, OwnableUpgradeable {
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

    uint256 public constant DENOMINATOR = 100_000;

    /// @dev Determines if the Asset is the gUSD or the scvUSD
    bool isGUSD;

    ILendRewardSplitter public lendRewardSplitter;

    ISDLiquidityGauge public liquidityGauge;

    /// @notice Percentage of rewards to be sent to the user who processed the GOV rewards
    uint256 public processorRewardsPercentage; //Question: same fee percentage for all tokens ?

    /// @notice Percentage of GOV rewards to be sent to the splitter and claimed by the DAO
    uint256 public daoFeesPercentage; //Question: same fee percentage for all tokens ?

    /// @dev List of reward tokens
    IERC20[] public rewardTokens;

    /// @dev Reward data associated to a reward token
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @dev Reward amount already sent to an user for a reward token
    mapping(address => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // user => reward token => amount

    /// @dev Reward amount for a reward token for a user
    mapping(address => mapping(IERC20 => uint256)) public rewards; // user => reward token => amount

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);

    error WrongToken();
    error MarketNotExists(address requestedMarket);
    error NoRewardToProcess();

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
        address _lendRewardSplitter,
        address _liquidityGauge,
        bool _isGUSD
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);
        processorRewardsPercentage = 1000; /// @dev TODO: TO CHANGE -> corresponds to 1%
        daoFeesPercentage = 2000; /// @dev TODO: TO CHANGE -> corresponds to 2%
        lendRewardSplitter = ILendRewardSplitter(_lendRewardSplitter);
        liquidityGauge = ISDLiquidityGauge(_liquidityGauge);
        isGUSD = _isGUSD;
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
     * @notice Claim all pending rewards for an address
     * @dev Only lendRewardSplitter can call this function,
     *      returns a TokenAmount[] struct and the rewards receiver address
     * @param _address Address to claim rewards for
     */
    struct TokenAmount {
        IERC20 token;
        uint256 amount;
    }

    function getReward(address _address) external updateReward(_address) returns (TokenAmount[] memory) {
        require(msg.sender == address(lendRewardSplitter), "NOT_SPLITTER");
        uint256 rewardTokensLength = rewardTokens.length;
        TokenAmount[] memory tokenAmounts = new TokenAmount[](rewardTokensLength);

        uint256 counter;
        for (uint256 i; i < rewardTokensLength; ) {
            IERC20 _rewardToken = rewardTokens[i];
            uint256 reward = rewards[_address][_rewardToken];

            if (reward > 0) {
                rewards[_address][_rewardToken] = 0;
                tokenAmounts[counter++] = TokenAmount({token: _rewardToken, amount: reward});
                emit RewardPaid(_address, _rewardToken, reward);
            }

            unchecked {
                ++i;
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

    /**
     * @notice Process Stable Rewards (only for scvUSD)
     * @dev Claim rewards from the splitter share  and stream it for the holders of scvUSD.
     *   Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processStableRewards(address _market) external returns (uint256 rewardToProcess) {
        if (isGUSD) revert WrongToken();

        ILendRewardSplitter.MarketStruct memory market = lendRewardSplitter.getMarket(_market);
        if (address(market.scvUSD) != address(this)) revert MarketNotExists(_market);

        /// @dev if the reward is not added we Add it.
        IERC20[] memory _rewardsToken = rewardTokens;
        if (_rewardsToken.length == 0) {
            _addReward(market.lendAsset);
        }
        uint256 daoFeesToUpdate;
        /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply.
        uint256 rewardShare = market.liquidityGauge.balanceOf(address(lendRewardSplitter)) -
            totalSupply() -
            market.curveLendVault.convertToAssets(market.gUSD.totalSupply());

        /// @dev We withdraw the reward share from the splitter
        lendRewardSplitter.withdrawForRewards(_market, rewardShare);

        /// @dev The balance of market lendAsset on this contract is the amount to proceed.
        rewardToProcess = rewardTokens[0].balanceOf(address(this));
        if (rewardToProcess == 0) {
            revert NoRewardToProcess();
        }

        /// @dev We process the  processorFess.
        uint256 processorFees = (rewardToProcess * processorRewardsPercentage) / DENOMINATOR;
        if (processorFees != 0) {
            rewardTokens[0].safeTransfer(msg.sender, processorFees);
            rewardToProcess -= processorFees;
        }

        /// @dev We process the daoFees.
        uint256 daoFees = (rewardToProcess * daoFeesPercentage) / DENOMINATOR;
        /// @dev Send reward to process + DAO fees to the splitter
        rewardTokens[0].safeTransfer(address(lendRewardSplitter), rewardToProcess);

        /// @dev DAO fees update.
        if (daoFees != 0) {
            daoFeesToUpdate = daoFees;
            rewardToProcess -= daoFees;
        }

        /// @dev Stream rewards.
        _notifyRewardAmount(rewardTokens[0], rewardToProcess);

        /// @dev Update DAO fees on the splitter contract.
        uint256[] memory daoFeesList = new uint256[](1);
        daoFeesList[0] = daoFeesToUpdate;
        lendRewardSplitter.updateDaoFees(rewardTokens, daoFeesList);
    }

    /**
     * @notice Process Governance Rewards (only for gUSD)
     * @dev Claim rewards from the splitter and stream it for the holders of gUSD.
     *      Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processGovRewards() external {
        if (!isGUSD) revert WrongToken();

        /// @dev Claim rewards on behalf of the splitter on this contract
        liquidityGauge.claim_rewards(address(lendRewardSplitter));

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
                    _rewardTokens[i].safeTransfer(msg.sender, processorFees);
                    rewardToProcess -= processorFees;
                }

                /// @dev Send reward to process + DAO fees to the splitter
                _rewardTokens[i].safeTransfer(address(lendRewardSplitter), rewardToProcess);

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
        ISDLiquidityGauge _liquidityGauge = liquidityGauge;
        uint256 rewardCount = _liquidityGauge.reward_count();
        for (uint256 i = currentRewardTokens; i < rewardCount; ) {
            IERC20 rewardToken = IERC20(_liquidityGauge.reward_tokens(i));
            _addReward(rewardToken);
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
        // console.log("_notifyRewardAmount", "set lastUpdateTime", rData.lastUpdateTime);
        // console.log("_notifyRewardAmount", "set periodFinish", rData.periodFinish);
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
     * @notice Set the percentage of rewards to be sent to the user processing the GOV rewards.
     * @param _percentage rewards percentage value
     */
    function setProcessorRewardsPercentage(uint256 _percentage) external onlyOwner {
        /// @dev it must never exceed 3% (TODO: ???)
        require(_percentage <= 3000, "PERCENTAGE_TOO_HIGH");
        processorRewardsPercentage = _percentage;
    }

    /**
     * @notice Set the percentage of rewards to be sent to the splitter as a DAO fees.
     * @param _percentage rewards percentage value
     */
    function setDaoFeesPercentage(uint256 _percentage) external onlyOwner {
        /// @dev it must never exceed 3% (TODO: ???)
        require(_percentage <= 3000, "PERCENTAGE_TOO_HIGH");
        daoFeesPercentage = _percentage;
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

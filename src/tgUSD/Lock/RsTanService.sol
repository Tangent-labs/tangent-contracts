// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC4626, IERC20} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IRsTanERC721} from "../../interfaces/internals/tgUSD/IRsTanERC721.sol";

import {Reward, TokenAmount} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";

import {LightOwnable} from "../Utilities/LightOwnable.sol";

/// @notice
contract RsTanService is LightOwnable {
    using SafeERC20 for IERC20;
    /// @notice Duration for which tokens are locked (13 weeks).
    uint256 public constant LOCK_DURATION = 13 weeks;
    /// @notice One week in seconds.
    uint256 internal constant ONE_WEEK = 1 weeks;
    /// @notice Maximum value for a uint48.
    uint48 public constant MAX_UINT48 = type(uint48).max;

    /// @notice Tangent token. Token that the user locks.
    IERC20 public tan;

    /// @notice Tangent USD - tgUSD stablecoin.
    IERC20 public tgUSD;

    IERC4626 public sgUSD;

    IRsTanERC721 public rsTanERC721;

    /// @notice Parameters for the kick mechanism.
    KickParams public kick;

    /// @notice Reference to the control tower contract.
    IControlTower public controlTower;

    /// @notice Total amount of locked tokens.
    uint256 public totalSupplyRsTan;

    /// @notice Mapping of token IDs to their lock details.
    mapping(uint256 => Lock) public locks;

    /// @dev Struct representing a locked position.
    /// @param endLockTime The timestamp when the lock ends.
    /// @param amount The amount of tokens locked.
    struct Lock {
        uint48 endLockTime;
        uint208 amount;
    }

    /// @dev Struct representing kick parameters.
    /// @param delay Delay before a position can be kicked.
    /// @param percentage Percentage of the locked amount to be penalized.
    struct KickParams {
        uint128 delay;
        uint128 percentage;
    }

    /// @notice List of reward tokens
    IERC20[] public rewardTokens;

    /// @notice Mapping of reward tokens to their reward data.
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @notice Mapping of user reward per token paid.
    /// @dev Tracks rewards paid to users for each token.
    mapping(uint256 => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // position => reward token => amount

    /// @notice Mapping of claimable rewards for each token.
    mapping(uint256 => mapping(IERC20 => uint256)) public rewards; // position => reward token => amount

    error ZeroAmount();
    error NotTokenOwner();
    error NotPermaLocked();
    error AlreadyPermaLocked();
    error LockNotOver();
    error BiggerThanInitialPosition();
    error LockExpired();
    error CantIncreaseTimePermaLock();
    error AlreadyMaxLock();
    error KickDelayIsNotPassed();

    error HarvesterFeeToHigh();
    error NothingToClaim();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);
    error RewardNotAdded(IERC20 erc20);

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(uint256 indexed tokenId, IERC20 indexed _rewardToken, uint256 _reward);

    constructor(address _owner, IControlTower _controlTower, IERC20 _tan, IRsTanERC721 _rsTanERC721, IERC20 _tgUSD, IERC4626 _sgUSD) {
        _transferOwnership(_owner);

        controlTower = _controlTower;
        tan = _tan;
        rsTanERC721 = _rsTanERC721;
        tgUSD = _tgUSD;
        sgUSD = _sgUSD;

        _tgUSD.approve(address(_sgUSD), type(uint256).max);

        kick = KickParams({delay: uint128(ONE_WEEK), percentage: uint128(250)});
    }

    modifier updateReward(uint256 tokenId) {
        _updateReward(tokenId);
        _;
    }

    /**
     * @notice Update reward data for every reward tokens for a position
     * @param tokenId Position ID
     */
    function _updateReward(uint256 tokenId) internal {
        uint256 positionBal = locks[tokenId].amount;
        uint256 rewardLength = rewardTokens.length;
        for (uint256 i; i < rewardLength; ) {
            IERC20 token = rewardTokens[i];

            rewardData[token].rewardPerTokenStored = _rewardPerToken(token);
            rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(rewardData[token].periodFinish);

            if (tokenId != 0) {
                rewards[tokenId][token] = _earned(tokenId, token, positionBal);
                userRewardPerTokenPaid[tokenId][token] = rewardData[token].rewardPerTokenStored;
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

    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardTokens;
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
        if (totalSupplyRsTan == 0) {
            return rewardData[_rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) - rewardData[_rewardToken].lastUpdateTime) * rewardData[_rewardToken].rewardRate * 1e18) /
                totalSupplyRsTan);
    }

    /**
     * @notice Fetch the amount earned
     * @param tokenId Id of the locking position
     * @param _rewardToken Address of the reward token
     * @param _balance Balance
     * @return Reward amount to claim for the user
     */
    function _earned(uint256 tokenId, IERC20 _rewardToken, uint256 _balance) internal view returns (uint256) {
        return (_balance * (_rewardPerToken(_rewardToken) - userRewardPerTokenPaid[tokenId][_rewardToken])) / 1e18 + rewards[tokenId][_rewardToken];
    }

    function _lastTimeRewardApplicable(uint128 _finishTime) internal view returns (uint128) {
        return block.timestamp < _finishTime ? uint128(block.timestamp) : uint128(_finishTime);
    }

    /**
     * @notice Check if the caller is a zapper and return the appropriate address
     * @param  callerZapper Address of the
     * @return isZapping Boolean indicating if the caller is a zapper
     * @return caller Address of the caller or zapper
     */
    function _checkZapper(address callerZapper) internal view returns (bool, address) {
        bool isZapping;
        if (address(callerZapper) != address(0)) {
            isZapping = controlTower.isZapper(msg.sender);
        } else {
            callerZapper = msg.sender;
        }
        callerZapper = isZapping ? callerZapper : msg.sender;

        return (isZapping, callerZapper);
    }

    /**
     * @notice Get the lock details for a specific token ID
     * @param tokenId ID of the locking position
     * @return endLockTime The end time of the lock
     * @return amount The amount locked
     */
    function _getLock(uint256 tokenId) internal view returns (uint48, uint208) {
        Lock memory lock = locks[tokenId];
        return (lock.endLockTime, lock.amount);
    }

    /**
     * @notice Create a new lock for the specified amount
     * @param amountIn Amount of tokens to lock
     * @param isPermaLock Boolean indicating if the lock is permanent
     * @param callerZapper Address of the zapper (if applicable)
     */
    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external {
        require(amountIn != 0, ZeroAmount());
        (bool isZap, address receiver) = _checkZapper(callerZapper);

        uint256 tokenId = rsTanERC721.mintForCreate(receiver);

        _updateReward(tokenId);

        // Store the position information
        locks[tokenId] = Lock({endLockTime: isPermaLock ? MAX_UINT48 : _newEndLockTime(), amount: amountIn});
        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    /**
     * @notice Increase the amount of an existing lock
     * @param tokenId ID of the locking position
     * @param amountIn Amount to add to the lock
     * @param callerZapper Address of the zapper (if applicable)
     */
    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external updateReward(tokenId) {
        require(amountIn != 0, ZeroAmount());
        (uint48 oldLockTime, uint208 oldAmount) = _getLock(tokenId);
        require(oldLockTime > block.timestamp, LockExpired());

        (bool isZap, address tokenOwner) = _checkZapper(callerZapper);

        require(rsTanERC721.ownerOf(tokenId) == tokenOwner, NotTokenOwner());

        locks[tokenId] = Lock({endLockTime: oldLockTime != MAX_UINT48 ? _newEndLockTime() : MAX_UINT48, amount: oldAmount + amountIn});

        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    /**
     * @notice Increase the lock duration for a specific token
     * @param tokenId ID of the locking position
     */
    function increaseLockTime(uint256 tokenId) external {
        require(rsTanERC721.ownerOf(tokenId) == msg.sender, NotTokenOwner());

        uint48 oldEndLockTime = locks[tokenId].endLockTime;
        // Cant increase time a position already expired
        require(oldEndLockTime > block.timestamp, LockExpired());
        // Cant increase time a position perma locked
        require(oldEndLockTime != MAX_UINT48, CantIncreaseTimePermaLock());
        uint48 newEnd = _newEndLockTime();
        // Cant increase time a position alreadyMaxLocked
        require(oldEndLockTime != newEnd, AlreadyMaxLock());

        //
        locks[tokenId].endLockTime = newEnd;
    }

    /**
     * @notice Toggle the lock to permanent or revert it to a timed lock
     * @param tokenId ID of the locking position
     */
    function togglePermaLock(uint256 tokenId) external {
        require(rsTanERC721.ownerOf(tokenId) == msg.sender, NotTokenOwner());

        uint48 oldEndLockTime = locks[tokenId].endLockTime;
        require(oldEndLockTime > block.timestamp, LockExpired());
        locks[tokenId].endLockTime = oldEndLockTime != MAX_UINT48 ? MAX_UINT48 : _newEndLockTime();
    }

    /**
     * @notice Unlock a position after the lock period has ended
     * @param tokenId ID of the locking position
     */
    function unlock(uint256 tokenId) external updateReward(0) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        require(endLockTime < block.timestamp, LockNotOver());

        rsTanERC721.burnForUnlock(tokenId, msg.sender);

        totalSupplyRsTan -= amount;
        delete locks[tokenId];

        tan.transfer(msg.sender, amount);
    }

    /**
     * @notice Exit a lock position early with a penalty
     * @param tokenId ID of the locking position
     */
    function rageQuit(uint256 tokenId) external updateReward(0) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        bool isPermaLocked = endLockTime == MAX_UINT48;

        // If a position is not permalocked
        // Remove it from the checkpoint where the lock was supposed to finish

        require(endLockTime > block.timestamp, LockExpired());

        // Remove the amount locked from the total supply as it will not be triggered by the checkpoint
        totalSupplyRsTan -= amount;

        uint256 penalty = (amount * ((isPermaLocked ? _newEndLockTime() : endLockTime) - block.timestamp)) / LOCK_DURATION;

        rsTanERC721.burnForUnlock(tokenId, msg.sender);
        delete locks[tokenId];

        tan.transfer(msg.sender, amount - penalty);
        tan.transfer(controlTower.feeTreasury(), penalty);
    }

    /**
     * @notice Kick a position after the lock period and delay have passed
     * @param tokenId ID of the locking position
     * @param receiver Address to receive the kick incentive
     */
    function kickPosition(uint256 tokenId, address receiver) external updateReward(0) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        KickParams memory _kick = kick;

        require(block.timestamp > endLockTime + _kick.delay, KickDelayIsNotPassed());

        uint256 kickIncentivization = (_kick.percentage * amount) / 100_000;

        address tokenOwner = rsTanERC721.burKickPosition(tokenId);

        tan.transfer(tokenOwner, amount - kickIncentivization);
        tan.transfer(receiver, kickIncentivization);

        delete locks[tokenId];
    }

    /**
     * @notice Split a locked position into two separate positions
     * @param tokenId ID of the original locking position
     * @param amountToRemove Amount to remove from the original position
     */
    function split(uint256 tokenId, uint208 amountToRemove) external updateReward(0) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);

        require(amountToRemove != 0, ZeroAmount());
        require(amountToRemove < amount, BiggerThanInitialPosition());
        require(endLockTime > block.timestamp, LockExpired());

        uint256 newId = rsTanERC721.mintForSplit(msg.sender, tokenId);

        locks[newId] = Lock({endLockTime: endLockTime, amount: amountToRemove});
        locks[tokenId].amount = amount - amountToRemove;
    }

    /**
     * @notice Merge two locked positions into one
     * @dev    Burns the second token ID and adds the amount to the first token ID
     * @param tokenIdA ID of the first locking position. Receives the amount of the second position.
     * @param tokenIdB ID of the second locking position. Is burnt in the process
     */
    function merge(uint256 tokenIdA, uint256 tokenIdB) external {
        (uint48 endLockA, uint208 amountA) = _getLock(tokenIdA);
        (uint48 endLockB, uint208 amountB) = _getLock(tokenIdB);

        require(endLockA > block.timestamp, LockExpired());
        require(endLockB > block.timestamp, LockExpired());

        locks[tokenIdA] = Lock({endLockTime: endLockA < endLockB ? endLockB : endLockA, amount: amountA + amountB});
        delete locks[tokenIdB];
        rsTanERC721.burnForMerge(tokenIdA, tokenIdB, msg.sender);
    }

    /**
     * @notice Get the next end lock time based on the current timestamp
     * @return The next end lock time
     */
    function nextEndLockTime() external view returns (uint48) {
        return _newEndLockTime();
    }

    /**
     * @notice Calculate the new end lock time based on the current timestamp
     * @return The new end lock time
     */
    function _newEndLockTime() internal view returns (uint48) {
        return uint48(((block.timestamp + LOCK_DURATION) / ONE_WEEK) * ONE_WEEK);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Add a new reward token to the contract
     * @param _newRewardToken Address of the new reward token
     */
    function addNewReward(IERC20 _newRewardToken) external onlyOwner {
        /// @dev If lastUpdateTime is equal to 0, it means the token is not already added as a reward
        require(rewardData[_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

        rewardTokens.push(_newRewardToken);
        rewardData[_newRewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_newRewardToken].periodFinish = uint128(block.timestamp);
    }

    /**
     * @notice Process rewards for the specified reward tokens
     * @param tokenAmounts Array of reward tokens and their amounts to distribute
     */
    function processRewards(TokenAmount[] memory tokenAmounts) external onlyOwner {
        // Reward tokens updated
        uint256 rewardTokensLength = tokenAmounts.length;

        for (uint256 i; i < rewardTokensLength; ) {
            IERC20 rewardToken = tokenAmounts[i].token;
            uint256 amount = tokenAmounts[i].amount;

            Reward memory rData = rewardData[rewardToken];

            require(0 != rData.lastUpdateTime, RewardNotAdded(rewardToken));
            require(0 != amount, ZeroAmount());

            if (block.timestamp >= rData.periodFinish) {
                rewardData[rewardToken].rewardRate = amount / ONE_WEEK;
            } else {
                uint256 leftover = (rData.periodFinish - block.timestamp) * rData.rewardRate;
                rewardData[rewardToken].rewardRate = (amount + leftover) / ONE_WEEK;
            }

            rewardData[rewardToken].lastUpdateTime = uint128(block.timestamp);
            rewardData[rewardToken].periodFinish = uint128(block.timestamp + ONE_WEEK);

            rewardToken.transferFrom(msg.sender, address(this), amount);

            emit RewardNotified(rewardToken, amount);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Claim all pending rewards for a locking position
     * @dev Only the owner of the position can call the function
     * @param tokenId ID of the position to claim
     */
    function claimSimple(uint256 tokenId, bool isClaimAsSgUSD) external updateReward(tokenId) {
        require(rsTanERC721.ownerOf(tokenId) == msg.sender, NotTokenOwner());

        uint256 rewardTokensLength = rewardTokens.length;

        bool isClaimable;
        IERC20 _tgUSD = tgUSD;
        IERC4626 _sgUSD = sgUSD;

        for (uint256 rewardIndex; rewardIndex < rewardTokensLength; ) {
            IERC20 _rewardToken = rewardTokens[rewardIndex];
            uint256 rewardAmount = rewards[tokenId][_rewardToken];

            if (rewardAmount > 0) {
                isClaimable = true;
                rewards[tokenId][_rewardToken] = 0;
                if (_rewardToken == _tgUSD && isClaimAsSgUSD) {
                    _sgUSD.deposit(rewardAmount, msg.sender);
                } else {
                    _rewardToken.transfer(msg.sender, rewardAmount);
                }
                emit RewardPaid(tokenId, _rewardToken, rewardAmount);
            }

            unchecked {
                ++rewardIndex;
            }
        }

        require(isClaimable, NothingToClaim());
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param positionIds Array of position IDs to claim rewards from
     */
    function claimMultiple(uint256[] calldata positionIds, bool isClaimAsSgUSD) external {
        // User input verification
        rsTanERC721.verifyTokenIdsOwned(msg.sender, positionIds);
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 positionsLen = positionIds.length;
        uint256 rewardTokenLen = rewardTokens.length;
        TokenAmount[] memory tokenAmount = new TokenAmount[](rewardTokens.length);

        // Initialize TokenAmount array
        for (uint256 i; i < tokenAmount.length; ) {
            tokenAmount[i] = TokenAmount({token: rewardTokens[i], amount: 0});
            unchecked {
                ++i;
            }
        }

        IERC20 _tgUSD = tgUSD;
        IERC4626 _sgUSD = sgUSD;

        // Iterates through all of the vaults
        for (uint256 positionIndex; positionIndex < positionsLen; ) {
            uint256 positionId = positionIds[positionIndex];

            _updateReward(positionId);

            // If the rewards returned by the gUSD is an empty array,
            bool isClaimable;

            for (uint256 rewardIndex; rewardIndex < rewardTokenLen; ) {
                IERC20 _rewardToken = rewardTokens[rewardIndex];
                uint256 reward = rewards[positionId][_rewardToken];

                if (reward > 0) {
                    isClaimable = true;
                    rewards[positionId][_rewardToken] = 0;

                    emit RewardPaid(positionId, _rewardToken, reward);
                    tokenAmount[rewardIndex].amount += reward;
                }

                unchecked {
                    ++rewardIndex;
                }
            }
            require(isClaimable, NothingToClaim());

            unchecked {
                ++positionIndex;
            }
        }

        // Iterate through tokenList
        for (uint256 rewardIndex; rewardIndex < tokenAmount.length; ) {
            IERC20 token = tokenAmount[rewardIndex].token;
            uint256 amount = tokenAmount[rewardIndex].amount;

            if (amount != 0) {
                if (token == _tgUSD && isClaimAsSgUSD) {
                    _sgUSD.deposit(amount, msg.sender);
                } else {
                    token.transfer(msg.sender, amount);
                }
            }

            unchecked {
                ++rewardIndex;
            }
        }
    }

    /**
     * @notice Get the claimable amount of all reward tokens for the given address
     * @param  tokenId Address of the user
     * @return userRewards Array of rewards claimable by the position
     */
    function claimableRewards(uint256 tokenId) external view returns (TokenAmount[] memory userRewards) {
        userRewards = new TokenAmount[](rewardTokens.length);

        uint256 rsTanBalance = locks[tokenId].amount;
        for (uint256 erc20Id; erc20Id < userRewards.length; ) {
            IERC20 token = rewardTokens[erc20Id];
            userRewards[erc20Id].token = token;
            userRewards[erc20Id].amount = _earned(tokenId, token, rsTanBalance);

            unchecked {
                ++erc20Id;
            }
        }

        return userRewards;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC4626, IERC20} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";

import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

import {ZapStructDeposit} from "../../interfaces/internals/ICommonStruct.sol";

import {Reward, TokenAmount} from "../../interfaces/internals/USG/IRewardAccumulator.sol";

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";
import {ZappingUtil} from "../Utilities/abstract/ZappingUtil.sol";
import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

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

/// @title VsTan
/// @notice Locking NFT contract of TAN.
contract VsTan is LightOwnable, LightReentrancyGuardTransient, ERC721Enumerable, ZappingUtil {
    using SafeERC20 for IERC20;
    /// @notice Duration for which tokens are locked (13 weeks).
    uint256 public constant LOCK_DURATION = 13 weeks;
    /// @notice One week in seconds.
    uint256 internal constant ONE_WEEK = 1 weeks;
    /// @notice Maximum value for a uint48.
    uint48 public constant MAX_UINT48 = type(uint48).max;

    uint256 public nextId = 1;

    /// @notice Tangent token. Token that the user locks.
    IERC20 public tan;

    /// @notice Tangent USD - USG stablecoin.
    IERC20 public USG;

    IERC4626 public sUSG;

    /// @notice Parameters for the kick mechanism.
    KickParams public kick;

    /// @notice Reference to the control tower contract.
    IControlTower public controlTower;

    /// @notice Total amount of locked tokens.
    uint256 public totalSupplyVsTan;

    /// @notice Mapping of token IDs to their lock details.
    mapping(uint256 => Lock) public locks;

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
    error CantMerge2SamePosition();

    error HarvesterFeeToHigh();
    error NothingToClaim();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);
    error RewardNotAdded(IERC20 erc20);

    error KickDelayTooShort();
    error KickDelayTooLong();
    error KickPercentageTooHigh();

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(uint256 indexed tokenId, IERC20 indexed _rewardToken, uint256 _reward);

    /**
     * @dev   Constructor of the contract
     * @param _owner        Owner of VsTan
     * @param _controlTower Keep controlTower for fetching the fee treasury
     * @param _tan          Tan token that is locked
     * @param _USG        USG token
     * @param _sUSG        sUSG token
     * @param _zappingProxy Zapping proxy contract used for zapping to TAN
     */
    constructor(address _owner, IControlTower _controlTower, IERC20 _tan, IERC20 _USG, IERC4626 _sUSG, IZappingProxy _zappingProxy) ERC721("VsTan", "VsTan") {
        _transferOwnership(_owner);

        controlTower = _controlTower;
        tan = _tan;
        USG = _USG;
        sUSG = _sUSG;
        zappingProxy = _zappingProxy;

        // Allow sUSG to spend USG for zapping USG to sUSG
        _USG.approve(address(_sUSG), type(uint256).max);

        kick = KickParams({delay: uint128(ONE_WEEK), percentage: uint128(250)});
    }

    /**
     * @dev Modifier used to verify if tyhe caller is the owner of the position in parameter
     * @param tokenId TokenId to verify the owner
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, NotTokenOwner());
        _;
    }

    /**
     * @dev Modifier used to verify if tyhe caller is the owner of the position in parameter
     * @param tokenId TokenId to checkpoint the
     */
    modifier updateReward(uint256 tokenId) {
        _updateReward(tokenId);
        _;
    }

    modifier isReentrancyGuartEntered() {
        require(!_reentrancyGuardEntered(), ReentrancyGuardReentrantCall());
        _;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       EXTERNAL USER 
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Create a new lock for the specified amount
     * @param amountIn Amount of tokens to lock
     * @param isPermaLock Boolean indicating if the lock is permanent
     */
    function createLock(uint208 amountIn, bool isPermaLock) external nonReentrant {
        _createLock(amountIn, isPermaLock);

        tan.transferFrom(msg.sender, address(this), amountIn);
    }

    function zapCreateLock(bool isPermalock, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 amountIn = _zapDeposit(zapCall, tan, address(this));
        _createLock(uint208(amountIn), isPermalock);
    }

    /**
     * @notice Increase the amount of an existing lock
     * @param tokenId ID of the locking position
     * @param amountIn Amount to add to the lock
     */
    function increaseLockAmount(uint256 tokenId, uint208 amountIn) external nonReentrant {
        _increaseLockAmount(tokenId, amountIn);

        tan.transferFrom(msg.sender, address(this), amountIn);
    }

    /**
     * @notice Increase the amount of an existing lock
     * @param tokenId ID of the locking position
     * @param zapCall Packed struct with the zap parameters
     */
    function zapIncreaseLockAmount(uint256 tokenId, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 amountIn = _zapDeposit(zapCall, tan, address(this));
        _increaseLockAmount(tokenId, uint208(amountIn));
    }

    /**
     * @notice Increase the lock duration for a specific token
     * @param tokenId ID of the locking position
     */
    function increaseLockTime(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) {
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
    function togglePermaLock(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) {
        uint48 oldEndLockTime = locks[tokenId].endLockTime;
        require(oldEndLockTime > block.timestamp, LockExpired());
        locks[tokenId].endLockTime = oldEndLockTime != MAX_UINT48 ? MAX_UINT48 : _newEndLockTime();
    }

    /**
     * @notice Unlock a position after the lock period has ended
     * @param tokenId ID of the locking position
     */
    function unlock(uint256 tokenId, bool isClaimAssUSG) external nonReentrant onlyTokenOwner(tokenId) updateReward(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        require(endLockTime < block.timestamp, LockNotOver());

        totalSupplyVsTan -= amount;
        delete locks[tokenId];
        _burn(tokenId);

        _claimSimple(tokenId, msg.sender, isClaimAssUSG);
        tan.transfer(msg.sender, amount);
    }

    /**
     * @notice Exit a lock position early with a penalty
     * @param tokenId ID of the locking position
     */
    function rageQuit(uint256 tokenId, bool isClaimAssUSG) external nonReentrant onlyTokenOwner(tokenId) updateReward(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        bool isPermaLocked = endLockTime == MAX_UINT48;
        require(endLockTime > block.timestamp, LockExpired());
        uint256 penality = (amount * ((isPermaLocked ? _newEndLockTime() : endLockTime) - block.timestamp)) / LOCK_DURATION;

        // Remove the amount locked from the total supply as it will not be triggered by the checkpoint
        totalSupplyVsTan -= amount;
        delete locks[tokenId];
        _burn(tokenId);

        _claimSimple(tokenId, msg.sender, isClaimAssUSG);
        IERC20 _tan = tan;
        _tan.transfer(msg.sender, amount - penality);
        _tan.transfer(controlTower.feeTreasury(), penality);
    }

    /**
     * @notice Kick a position after the lock period and delay have passed
     * @param tokenId ID of the locking position
     * @param receiver Address to receive the kick incentive
     */
    function kickPosition(uint256 tokenId, address receiver) external nonReentrant updateReward(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        KickParams memory _kick = kick;
        require(block.timestamp > endLockTime + _kick.delay, KickDelayIsNotPassed());

        uint256 kickIncentivization = (_kick.percentage * amount) / 100_000;
        address tokenOwner = ownerOf(tokenId);

        totalSupplyVsTan -= amount;
        delete locks[tokenId];
        _burn(tokenId);

        _claimSimple(tokenId, tokenOwner, false);
        IERC20 _tan = tan;
        _tan.transfer(tokenOwner, amount - kickIncentivization);
        _tan.transfer(receiver, kickIncentivization);
    }

    /**
     * @notice Split a locked position into two separate positions
     * @param tokenId ID of the original locking position
     * @param amountToRemove Amount to remove from the original position
     */
    function split(uint256 tokenId, uint208 amountToRemove) external nonReentrant onlyTokenOwner(tokenId) updateReward(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);

        require(amountToRemove != 0, ZeroAmount());
        require(amountToRemove < amount, BiggerThanInitialPosition());
        require(endLockTime > block.timestamp, LockExpired());

        uint256 newTokenId = nextId++;
        _updateReward(newTokenId);
        locks[newTokenId] = Lock({endLockTime: endLockTime, amount: amountToRemove});
        locks[tokenId].amount = amount - amountToRemove;
        _mint(msg.sender, newTokenId);
    }

    /**
     * @notice Merge two locked positions into one
     * @dev    Burns the second token ID and adds the amount to the first token ID
     * @param tokenIdA ID of the first locking position. Receives the amount of the second position.
     * @param tokenIdB ID of the second locking position. Is burnt in the process
     */
    function merge(
        uint256 tokenIdA,
        uint256 tokenIdB,
        bool isClaimAssUSG
    ) external nonReentrant onlyTokenOwner(tokenIdA) onlyTokenOwner(tokenIdB) updateReward(tokenIdA) updateReward(tokenIdB) {
        require(tokenIdA != tokenIdB, CantMerge2SamePosition());
        (uint48 endLockA, uint208 amountA) = _getLock(tokenIdA);
        (uint48 endLockB, uint208 amountB) = _getLock(tokenIdB);

        require(endLockA > block.timestamp, LockExpired());
        require(endLockB > block.timestamp, LockExpired());

        locks[tokenIdA] = Lock({endLockTime: endLockA < endLockB ? endLockB : endLockA, amount: amountA + amountB});
        delete locks[tokenIdB];

        _burn(tokenIdB);
        _claimSimple(tokenIdB, msg.sender, isClaimAssUSG);
    }

    /**
     * @notice Claim all pending rewards for a locking position
     * @dev Only the owner of the position can call the function
     * @param tokenId ID of the position to claim
     */
    function claimSimple(uint256 tokenId, bool isClaimAssUSG) external nonReentrant onlyTokenOwner(tokenId) updateReward(tokenId) {
        bool isClaimable = _claimSimple(tokenId, msg.sender, isClaimAssUSG);
        require(isClaimable, NothingToClaim());
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param positionIds Array of position IDs to claim rewards from
     */
    function claimMultiple(uint256[] calldata positionIds, bool isClaimAssUSG) external nonReentrant {
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 positionsLen = positionIds.length;
        uint256 rewardTokenLen = rewardTokens.length;
        TokenAmount[] memory tokenAmount = new TokenAmount[](rewardTokenLen);

        // Initialize TokenAmount array
        for (uint256 i; i < tokenAmount.length; ) {
            tokenAmount[i] = TokenAmount({token: rewardTokens[i], amount: 0});
            unchecked {
                ++i;
            }
        }

        IERC20 _USG = USG;
        IERC4626 _sUSG = sUSG;

        // Iterates through all positions ID
        for (uint256 positionIndex; positionIndex < positionsLen; ) {
            uint256 positionId = positionIds[positionIndex];
            // Verify that msg.sender owns all the positions
            require(ownerOf(positionId) == msg.sender, NotTokenOwner());

            // Checkpoints rewards for the current position
            _updateReward(positionId);

            // Used to determine if there is something to claim on the current position
            bool isClaimable;

            // Now we iterate though all reward tokens
            for (uint256 rewardIndex; rewardIndex < rewardTokenLen; ) {
                IERC20 _rewardToken = rewardTokens[rewardIndex];
                // Fetch reward amount to claim for the current position
                uint256 reward = rewards[positionId][_rewardToken];

                // If there is something to claim
                if (reward > 0) {
                    // Updates the isClaimable flag
                    isClaimable = true;
                    // Remove rewards because it's getting claimed
                    rewards[positionId][_rewardToken] = 0;
                    // Increments the global reward array
                    tokenAmount[rewardIndex].amount += reward;
                    emit RewardPaid(positionId, _rewardToken, reward);
                }

                unchecked {
                    ++rewardIndex;
                }
            }
            // Revert if there is nothing to claim on a position input
            require(isClaimable, NothingToClaim());

            unchecked {
                ++positionIndex;
            }
        }

        // Iterate through the final TokenAmount list
        for (uint256 rewardIndex; rewardIndex < tokenAmount.length; ) {
            IERC20 token = tokenAmount[rewardIndex].token;
            uint256 amount = tokenAmount[rewardIndex].amount;

            if (amount != 0) {
                // User is able to claim USG directly in sUSG
                if (token == _USG && isClaimAssUSG) {
                    _sUSG.deposit(amount, msg.sender);
                } else {
                    token.safeTransfer(msg.sender, amount);
                }
            }

            unchecked {
                ++rewardIndex;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS 
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

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

    function _createLock(uint208 amountIn, bool isPermaLock) internal {
        require(amountIn != 0, ZeroAmount());

        uint256 tokenId = nextId++;
        _updateReward(tokenId);
        // Store the position information
        locks[tokenId] = Lock({endLockTime: isPermaLock ? MAX_UINT48 : _newEndLockTime(), amount: amountIn});
        // Increase the total amount locked
        totalSupplyVsTan += amountIn;
        _mint(msg.sender, tokenId);
    }

    function _increaseLockAmount(uint256 tokenId, uint208 amountIn) internal onlyTokenOwner(tokenId) updateReward(tokenId) {
        require(amountIn != 0, ZeroAmount());
        (uint48 oldLockTime, uint208 oldAmount) = _getLock(tokenId);
        require(oldLockTime > block.timestamp, LockExpired());

        locks[tokenId] = Lock({endLockTime: oldLockTime != MAX_UINT48 ? _newEndLockTime() : MAX_UINT48, amount: oldAmount + amountIn});
        // Increase the total amount locked
        totalSupplyVsTan += amountIn;
    }

    function _claimSimple(uint256 tokenId, address receiver, bool isClaimAssUSG) internal returns (bool) {
        uint256 rewardTokensLength = rewardTokens.length;

        bool isClaimable;
        IERC20 _USG = USG;

        for (uint256 rewardIndex; rewardIndex < rewardTokensLength; ) {
            IERC20 _rewardToken = rewardTokens[rewardIndex];
            uint256 rewardAmount = rewards[tokenId][_rewardToken];

            if (rewardAmount > 0) {
                isClaimable = true;
                rewards[tokenId][_rewardToken] = 0;
                if (_rewardToken == _USG && isClaimAssUSG) {
                    sUSG.deposit(rewardAmount, receiver);
                } else {
                    _rewardToken.safeTransfer(receiver, rewardAmount);
                }
                emit RewardPaid(tokenId, _rewardToken, rewardAmount);
            }

            unchecked {
                ++rewardIndex;
            }
        }

        return isClaimable;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Add a new reward token to be stream to lockers
     * @param _newRewardToken Address of the new reward token
     */
    function addNewReward(IERC20 _newRewardToken) external onlyOwner {
        // If lastUpdateTime is equal to 0, it means _newRewardToken is not for now a reward
        require(rewardData[_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

        rewardTokens.push(_newRewardToken);
        rewardData[_newRewardToken].lastUpdateTime = uint128(block.timestamp);
        rewardData[_newRewardToken].periodFinish = uint128(block.timestamp);
    }

    function setKick(KickParams calldata _newKickParams) external onlyOwner {
        // 1 day min
        require(_newKickParams.delay >= 1 days, KickDelayTooShort());
        // 4 weeks max
        require(_newKickParams.delay <= 4 weeks, KickDelayTooLong());
        // 20% max
        require(_newKickParams.percentage <= 20_000, KickPercentageTooHigh());

        kick = _newKickParams;
    }

    /**
     * @notice Process rewards for the specified reward tokens
     * @param tokenAmounts Array of reward tokens and their amounts to distribute
     */
    function processRewards(TokenAmount[] memory tokenAmounts) external onlyOwner updateReward(0) {
        // Reward tokens updated
        uint256 rewardTokensLength = tokenAmounts.length;
        uint256 timestamp = block.timestamp;

        for (uint256 i; i < rewardTokensLength; ) {
            IERC20 rewardToken = tokenAmounts[i].token;
            uint256 amount = tokenAmounts[i].amount;

            Reward memory rData = rewardData[rewardToken];

            require(0 != rData.lastUpdateTime, RewardNotAdded(rewardToken));
            //TODO This require is not enough as check. We cannot distributes less than a certain amount because we are loosing a lot of precision by dividing by ONE week to get the rate
            require(0 != amount, ZeroAmount());

            if (timestamp >= rData.periodFinish) {
                rewardData[rewardToken].rewardRate = amount / ONE_WEEK;
            } else {
                uint256 leftover = (rData.periodFinish - timestamp) * rData.rewardRate;
                rewardData[rewardToken].rewardRate = (amount + leftover) / ONE_WEEK;
            }

            rewardData[rewardToken].lastUpdateTime = uint128(timestamp);
            rewardData[rewardToken].periodFinish = uint128(timestamp + ONE_WEEK);

            rewardToken.safeTransferFrom(msg.sender, address(this), amount);

            emit RewardNotified(rewardToken, amount);

            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS VIEWS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Fetch the reward amount of a token based on the period
     * @param _rewardToken Address of the reward token
     * @return Total reward amount of the token
     */
    function _rewardPerToken(IERC20 _rewardToken) internal view returns (uint256) {
        if (totalSupplyVsTan == 0) {
            return rewardData[_rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish) - rewardData[_rewardToken].lastUpdateTime) * rewardData[_rewardToken].rewardRate * 1e18) /
                totalSupplyVsTan);
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
     * @notice Calculate the new end lock time based on the current timestamp
     * @return The new end lock time
     */
    function _newEndLockTime() internal view returns (uint48) {
        return uint48(((block.timestamp + LOCK_DURATION) / ONE_WEEK) * ONE_WEEK);
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

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function getRewardData(IERC20 erc20) external view isReentrancyGuartEntered returns (Reward memory) {
        return rewardData[erc20];
    }

    function lastTimeRewardApplicable(IERC20 _rewardToken) external view isReentrancyGuartEntered returns (uint256) {
        return _lastTimeRewardApplicable(rewardData[_rewardToken].periodFinish);
    }

    function rewardPerToken(IERC20 _rewardToken) external view isReentrancyGuartEntered returns (uint256) {
        return _rewardPerToken(_rewardToken);
    }

    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardTokens;
    }

    /**
     * @notice Get the next end lock time based on the current timestamp
     * @return The next end lock time
     */
    function nextEndLockTime() external view isReentrancyGuartEntered returns (uint48) {
        return _newEndLockTime();
    }

    /**
     * @notice Get the lock details for a specific token ID
     * @param tokenId ID of the locking position
     * @return Lock
     */
    function getLock(uint256 tokenId) external view isReentrancyGuartEntered returns (Lock memory) {
        return locks[tokenId];
    }

    /**
     * @notice Get the claimable amount of all reward tokens for the given address
     * @param  tokenId Address of the user
     * @return userRewards Array of rewards claimable by the position
     */
    function claimableRewards(uint256 tokenId) external view isReentrancyGuartEntered returns (TokenAmount[] memory userRewards) {
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

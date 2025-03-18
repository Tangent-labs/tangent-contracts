// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {Reward} from "../../interfaces/internals/tgUSD/IRewards.sol";

import {LightOwnable} from "../Utilities/LightOwnable.sol";

import "forge-std/console.sol";
/// @notice
contract RsTan is ERC721Enumerable, LightOwnable {
    uint256 public constant LOCK_DURATION = 13 weeks;
    uint256 public constant ONE_WEEK = 1 weeks;

    uint48 public constant MAX_UINT48 = type(uint48).max;

    IERC20 public immutable tan;

    KickParams public kick;

    IControlTower public controlTower;
    uint256 public totalSupplyRsTan;
    uint256 public nextId;

    mapping(uint256 => Lock) public locks;

    // Rewards

    /// @notice Percentage of reward of rewards to distribute to borrowers. 50_000 = 50%
    uint256 public rewardCutPercentage = 50_000;

    /// @notice Percentage of reward given to harvester. 1_000 = 1%
    uint256 public harvesterFeePercentage;

    /// @notice Receiver of all rewards produced by the market
    address public rsTanRewardAccumulator;

    /// @notice List of reward tokens
    IERC20[] public rewardTokens;

    /// @notice Reward data associated to a reward token
    mapping(IERC20 => Reward) public rewardData; // token => reward data

    /// @notice Reward amount already claimed to an user for a reward token
    mapping(uint256 => mapping(IERC20 => uint256)) public userRewardPerTokenPaid; // position => reward token => amount

    /// @notice Reward amount for a reward token for a user
    mapping(uint256 => mapping(IERC20 => uint256)) public rewards; // position => reward token => amount

    struct Lock {
        uint48 endLockTime;
        uint208 amount;
    }

    struct KickParams {
        uint128 delay;
        uint128 percentage;
    }

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
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    event RewardNotified(IERC20 indexed _token, uint256 _reward);
    event RewardPaid(address indexed _user, IERC20 indexed _rewardToken, uint256 _reward);
    event Recovered(IERC20 _token, uint256 _amount);
    event RewardAdded(IERC20 indexed _rewardToken);
    event RewardDistributorApproved(IERC20 indexed _reward, address indexed _distributor, bool _state);

    struct ZapToTan {
        address caller;
        uint256 minTanReceived;
        bytes routerCall;
    }
    constructor(IControlTower _controlTower, IERC20 _tan) ERC721("RsTan", "RsTan") {
        tan = _tan;
        nextId = 1;
        controlTower = _controlTower;
        kick = KickParams({delay: uint128(ONE_WEEK), percentage: uint128(2_000)});
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, NotTokenOwner());
        _;
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

    function _getLock(uint256 tokenId) internal view returns (uint48, uint208) {
        Lock memory lock = locks[tokenId];
        return (lock.endLockTime, lock.amount);
    }

    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external {
        require(amountIn != 0, ZeroAmount());
        (bool isZap, address receiver) = _checkZapper(callerZapper);

        uint256 tokenId = nextId++;
        uint48 endLockTime = isPermaLock ? MAX_UINT48 : _newEndLockTime();

        _mint(receiver, tokenId);

        _updateReward(tokenId);

        // Store the position information
        locks[tokenId] = Lock({endLockTime: endLockTime, amount: amountIn});
        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external updateReward(tokenId) {
        require(amountIn != 0, ZeroAmount());
        (uint48 oldLockTime, uint208 oldAmount) = _getLock(tokenId);
        require(oldLockTime > block.timestamp, LockExpired());

        (bool isZap, address tokenOwner) = _checkZapper(callerZapper);

        require(ownerOf(tokenId) == tokenOwner, NotTokenOwner());

        locks[tokenId] = Lock({endLockTime: oldLockTime != MAX_UINT48 ? _newEndLockTime() : MAX_UINT48, amount: oldAmount + amountIn});

        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    function increaseLockTime(uint256 tokenId) external onlyTokenOwner(tokenId) {
        (uint48 oldEndLockTime, ) = _getLock(tokenId);
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

    function togglePermaLock(uint256 tokenId) external onlyTokenOwner(tokenId) {
        (uint48 oldEndLockTime, ) = _getLock(tokenId);
        require(oldEndLockTime > block.timestamp, LockExpired());
        // Pass in perma lock

        locks[tokenId].endLockTime = oldEndLockTime != MAX_UINT48 ? MAX_UINT48 : _newEndLockTime();
    }

    function unlock(uint256 tokenId) external onlyTokenOwner(tokenId) updateReward(0) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        require(endLockTime < block.timestamp, LockNotOver());

        _burn(tokenId);

        totalSupplyRsTan -= amount;
        delete locks[tokenId];

        tan.transfer(msg.sender, amount);
    }

    function rageQuit(uint256 tokenId) external onlyTokenOwner(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        bool isPermaLocked = endLockTime == MAX_UINT48;

        // If a position is not permalocked
        // Remove it from the checkpoint where the lock was supposed to finish

        require(endLockTime > block.timestamp, LockExpired());

        // Remove the amount locked from the total supply as it will not be triggered by the checkpoint
        totalSupplyRsTan -= amount;

        uint256 penalty = (amount * ((isPermaLocked ? _newEndLockTime() : endLockTime) - block.timestamp)) / LOCK_DURATION;

        _burn(tokenId);
        delete locks[tokenId];

        tan.transfer(msg.sender, amount - penalty);
        tan.transfer(controlTower.feeTreasury(), penalty);
    }

    function kickPosition(uint256 tokenId, address receiver) external {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        KickParams memory _kick = kick;

        require(block.timestamp > endLockTime + _kick.delay, KickDelayIsNotPassed());

        uint256 kickIncentivization = (_kick.percentage * amount) / 100_000;

        tan.transfer(ownerOf(tokenId), amount - kickIncentivization);
        tan.transfer(receiver, kickIncentivization);

        _burn(tokenId);
        delete locks[tokenId];
    }

    function split(uint256 tokenId, uint208 amountToRemove) external onlyTokenOwner(tokenId) {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);

        require(amountToRemove != 0, ZeroAmount());
        require(amountToRemove < amount, BiggerThanInitialPosition());
        require(endLockTime > block.timestamp, LockExpired());

        uint256 newId = nextId++;
        locks[newId] = Lock({endLockTime: endLockTime, amount: amountToRemove});
        locks[tokenId].amount = amount - amountToRemove;
        _mint(msg.sender, newId);
    }

    function merge(uint256 tokenIdA, uint256 tokenIdB) external onlyTokenOwner(tokenIdA) onlyTokenOwner(tokenIdB) {
        (uint48 endLockA, uint208 amountA) = _getLock(tokenIdA);
        (uint48 endLockB, uint208 amountB) = _getLock(tokenIdB);

        require(endLockA > block.timestamp, LockExpired());
        require(endLockB > block.timestamp, LockExpired());

        locks[tokenIdA] = Lock({endLockTime: endLockA < endLockB ? endLockB : endLockA, amount: amountA + amountB});
        delete locks[tokenIdB];
        _burn(tokenIdB);
    }

    function nextEndLockTime() external view returns (uint48) {
        return _newEndLockTime();
    }

    function _newEndLockTime() internal view returns (uint48) {
        return uint48(((block.timestamp + LOCK_DURATION) / ONE_WEEK) * ONE_WEEK);
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
}

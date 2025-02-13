// SPDX-License-Identifier: UNLICENSED
import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

/// @notice
contract RsTan is ERC721Enumerable {
    uint256 public constant LOCK_DURATION = 13 weeks;
    uint256 public constant ONE_WEEK = 1 weeks;
    uint48 public constant MAX_UINT48 = type(uint48).max;

    IERC20 public immutable tan;
    IControlTower public controlTower;

    uint256 public totalSupplyRsTan;
    uint256 public nextCheckpoint;
    uint256 public nextId;

    mapping(uint256 => Lock) public locks;
    mapping(uint256 => uint256) public amountDecrFromTotal;

    struct Lock {
        uint48 endLockTime;
        uint208 amount;
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

    struct ZapToTan {
        address caller;
        uint256 minTanReceived;
        bytes routerCall;
    }
    constructor(IControlTower _controlTower, IERC20 _tan) ERC721("RsTan", "RsTan") {
        tan = _tan;
        nextCheckpoint = (block.timestamp / ONE_WEEK) * ONE_WEEK;
        nextId = 1;
        controlTower = _controlTower;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, NotTokenOwner());
        _;
    }
    modifier checkpointTotal() {
        _checkpoint();
        _;
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

    function createLock(uint208 amountIn, bool isPermaLock, address callerZapper) external checkpointTotal {
        require(amountIn != 0, ZeroAmount());
        (bool isZap, address receiver) = _checkZapper(callerZapper);

        uint256 tokenId = nextId++;
        uint48 endLockTime = isPermaLock ? MAX_UINT48 : _newEndLockTime();

        _mint(receiver, tokenId);

        // Store the position information
        locks[tokenId] = Lock({endLockTime: endLockTime, amount: amountIn});
        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        // If the position is not permalocked
        if (!isPermaLock) {
            amountDecrFromTotal[endLockTime] += amountIn;
        }

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    function increaseLockAmount(uint256 tokenId, uint208 amountIn, address callerZapper) external checkpointTotal {
        require(amountIn != 0, ZeroAmount());
        (uint48 oldLockTime, uint208 oldAmount) = _getLock(tokenId);
        require(oldLockTime > block.timestamp, LockExpired());

        (bool isZap, address owner) = _checkZapper(callerZapper);

        require(ownerOf(tokenId) == owner, NotTokenOwner());

        // Case the position is not perma locked
        if (oldLockTime != MAX_UINT48) {
            uint208 newAmount = oldAmount + amountIn;

            uint48 newEndLockTime = _newEndLockTime();
            //
            if (newEndLockTime != oldLockTime) {
                // No need anymore to decrement on the old end of the locking time
                amountDecrFromTotal[oldLockTime] -= oldAmount;
                // Store the new lock amount to be decremented on the new locking time
                amountDecrFromTotal[newEndLockTime] += newAmount;

                locks[tokenId] = Lock({endLockTime: newEndLockTime, amount: newAmount});
            }
            // If several actions are on the same week
            else {
                locks[tokenId].amount = newAmount;
                amountDecrFromTotal[oldLockTime] += amountIn;
            }
        }
        // Perma lock
        else {
            locks[tokenId].amount += amountIn;
        }

        // Increase the total amount locked
        totalSupplyRsTan += amountIn;

        if (!isZap) {
            tan.transferFrom(msg.sender, address(this), amountIn);
        }
    }

    function increaseLockTime(uint256 tokenId) external onlyTokenOwner(tokenId) checkpointTotal {
        (uint48 oldEndLockTime, uint208 amount) = _getLock(tokenId);
        // Cant increase time a position already expired
        require(oldEndLockTime > block.timestamp, LockExpired());
        // Cant increase time a position perma locked
        require(oldEndLockTime != MAX_UINT48, CantIncreaseTimePermaLock());
        uint48 newEnd = _newEndLockTime();
        // Cant increase time a position alreadyMaxLocked
        require(oldEndLockTime != newEnd, AlreadyMaxLock());

        //
        locks[tokenId].endLockTime = newEnd;
        amountDecrFromTotal[oldEndLockTime] -= amount;
        amountDecrFromTotal[newEnd] += amount;
    }

    function togglePermaLock(uint256 tokenId) external onlyTokenOwner(tokenId) checkpointTotal {
        (uint48 oldEndLockTime, uint208 amount) = _getLock(tokenId);

        // Pass in perma lock
        if (oldEndLockTime != MAX_UINT48) {
            require(oldEndLockTime > block.timestamp, LockExpired());
            locks[tokenId].endLockTime = MAX_UINT48;
            amountDecrFromTotal[oldEndLockTime] -= amount;
        }
        // Remove perma lock
        else {
            uint48 newEndLockTime = _newEndLockTime();
            locks[tokenId].endLockTime = newEndLockTime;
            amountDecrFromTotal[newEndLockTime] += amount;
        }
    }

    function unlock(uint256 tokenId) external onlyTokenOwner(tokenId) checkpointTotal {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        require(endLockTime < block.timestamp, LockNotOver());

        _burn(tokenId);

        tan.transfer(msg.sender, amount);
    }

    function rageQuit(uint256 tokenId) external onlyTokenOwner(tokenId) checkpointTotal {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);
        bool isPermaLocked = endLockTime == MAX_UINT48;

        // If a position is not permalocked
        // Remove it from the checkpoint where the lock was supposed to finish
        if (!isPermaLocked) {
            amountDecrFromTotal[endLockTime] -= amount;
            require(endLockTime > block.timestamp, LockExpired());
        }

        // Remove the amount locked from the total supply as it will not be triggered by the checkpoint
        totalSupplyRsTan -= amount;

        uint256 penalty = (amount * ((isPermaLocked ? _newEndLockTime() : endLockTime) - block.timestamp)) / LOCK_DURATION;

        _burn(tokenId);

        tan.transfer(msg.sender, amount - penalty);
        tan.transfer(controlTower.feeTreasury(), penalty);
    }

    function split(uint256 tokenId, uint208 amountToRemove) external onlyTokenOwner(tokenId) checkpointTotal {
        (uint48 endLockTime, uint208 amount) = _getLock(tokenId);

        require(amountToRemove != 0, ZeroAmount());
        require(amountToRemove < amount, BiggerThanInitialPosition());
        require(endLockTime > block.timestamp, LockExpired());

        uint256 newId = nextId++;
        locks[newId] = Lock({endLockTime: endLockTime, amount: amountToRemove});
        locks[tokenId].amount = amount - amountToRemove;
        _mint(msg.sender, newId);
    }

    function merge(uint256 tokenIdA, uint256 tokenIdB) external onlyTokenOwner(tokenIdA) onlyTokenOwner(tokenIdB) checkpointTotal {
        (uint48 endLockA, uint208 amountA) = _getLock(tokenIdA);
        (uint48 endLockB, uint208 amountB) = _getLock(tokenIdB);

        require(endLockA > block.timestamp, LockExpired());
        require(endLockB > block.timestamp, LockExpired());

        uint48 oldestEndLock = endLockA < endLockB ? endLockB : endLockA;

        // Tokens doesn't have the 
        if (endLockA != endLockB) {
            // Remove the
            locks[tokenIdA] = Lock({endLockTime: oldestEndLock, amount: amountA + amountB});
            if (endLockA < endLockB) {
                amountDecrFromTotal[endLockA] -= amountA;
                amountDecrFromTotal[endLockB] += amountA;
            } else {
                amountDecrFromTotal[endLockB] -= amountB;
                amountDecrFromTotal[endLockA] += amountB;
            }
        }
        // Both token have the same end lock time ( checkpointed at same week or both permaLocked)
        else {
            locks[tokenIdA].amount += amountB;
        }

        _burn(tokenIdB);
    }

    function nextEndLockTime() external view returns (uint48) {
        return _newEndLockTime();
    }

    function _newEndLockTime() internal view returns (uint48) {
        return uint48(((block.timestamp + LOCK_DURATION) / ONE_WEEK) * ONE_WEEK);
    }

    function checkpoint() external {
        _checkpoint();
    }

    function _checkpoint() internal {
        uint256 _nextCheckpoint = nextCheckpoint;
        uint256 amountToReduce;
        bool isChange;

        for (_nextCheckpoint; _nextCheckpoint < block.timestamp; ) {
            isChange = true;
            // _nextCheckpoint += ONE_WEEK;
            amountToReduce += amountDecrFromTotal[_nextCheckpoint];
            _nextCheckpoint += ONE_WEEK;
        }

        if (isChange) {
            nextCheckpoint = _nextCheckpoint;
            if (amountToReduce != 0) {
                totalSupplyRsTan -= amountToReduce;
            }
        }
    }

    function totalSupplyRsTanCheckpointed() external view returns (uint256) {
        uint256 _nextCheckpoint = nextCheckpoint;
        uint256 amountToReduce;
        bool isChange;

        for (_nextCheckpoint; _nextCheckpoint < block.timestamp; ) {
            amountToReduce += amountDecrFromTotal[_nextCheckpoint];
            _nextCheckpoint += ONE_WEEK;
        }
        return totalSupplyRsTan - amountToReduce;
    }

    // function burn(uint256 amount) external {
    //     require(amount != 0, ZeroAmount());
    //     _burn(msg.sender, amount);
    // }
}

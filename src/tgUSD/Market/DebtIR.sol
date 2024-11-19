// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

/// @notice
abstract contract DebtIR is Ownable {
    using Math for uint256;
    uint256 public constant RAY = 1e27; // Facteur de précision ray (1 * 10^27)

    address public irMinter;

    /// @dev Global debt index. Represents the accumulation of the interest rate among time.
    uint256 public debtIndex;
    /// @dev Last total debt of the market.
    uint256 public lastDebt;
    /// @dev Last interest rate since previous interaction with the market. In RAY.
    uint256 public lastIR;
    /// @dev Last time interest rate has been updated.
    uint256 public blockLastIRTimestamp;
    /// @dev Total interest amount mintable by the system in tgUSD.
    uint256 public mintableInterests;

    /// @dev Maximum debt of the market
    uint256 public maxMarketDebt;

    /// @dev Loan minimum in tgUSD. We need it higher on L1 to keep liquidations profitable for liquidators
    uint256 public minimumLoan;

    /// @dev Debt in amount of tgUSD per user.
    mapping(address => uint256) public positionDebtIndex;

    error NotIRMinter();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function setMaxMarketDebt(uint256 _maxMarketDebt) external onlyOwner {
        maxMarketDebt = _maxMarketDebt;
    }
    function setMinimumLoan(uint256 _minimumLoan) external onlyOwner {
        minimumLoan = _minimumLoan;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        IR MINTER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function mintPendingInterests() external returns (uint256) {
        require(msg.sender == irMinter, NotIRMinter());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        _updateGlobalDebt(newDebtIndex, newTotalDebt);

        uint256 _mintableIterests = mintableInterests;
        delete mintableInterests;
        return _mintableIterests;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _updateDebts(address account, uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        /// @dev Recompute the new debt index of the user based on his new debt recomputed with interests and the new debtIndex
        positionDebtIndex[account] = newUserDebt.mulDiv(RAY, newDebtIndex, Math.Rounding.Floor);

        _updateGlobalDebt(newDebtIndex, newTotalDebt);
    }

    function _updateGlobalDebt(uint256 newDebtIndex, uint256 newTotalDebt) internal {
        /// @dev Update the debtIndex
        debtIndex = newDebtIndex;

        /// @dev Update the new debtIndex
        blockLastIRTimestamp = block.timestamp;

        lastDebt = newTotalDebt;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEBT & IR CHECKPOINTS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _indexIncrease(uint256 timeDelta) internal view returns (uint256) {
        uint256 _lastIr = lastIR;

        if (_lastIr != 0) {
            return _lastIr.mulDiv(timeDelta, 36500 days, Math.Rounding.Floor);
        } else {
            return 0;
        }
    }

    function _checkpointIR() internal returns (uint256, uint256) {
        /// @dev Time elapsed between
        uint256 timeDelta = block.timestamp - blockLastIRTimestamp;
        uint256 newTotalDebt = lastDebt;
        uint256 newDebtIndex = debtIndex;

        if (timeDelta != 0) {
            uint256 coeffIncrease = _indexIncrease(timeDelta);
            newDebtIndex += coeffIncrease;

            uint256 interestsGenerated = (newTotalDebt * coeffIncrease) / RAY;

            mintableInterests += interestsGenerated;

            newTotalDebt += interestsGenerated;
        }

        return (newDebtIndex, newTotalDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        GLOBAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function totalDebt() public view returns (uint256) {
        uint256 _lastDebt = lastDebt;
        return _lastDebt + _pendingInterests(_lastDebt);
    }
    function pendingInterests() public view returns (uint256) {
        return (lastDebt * _indexIncrease(block.timestamp - blockLastIRTimestamp)) / RAY;
    }

    function _pendingInterests(uint256 _lastDebt) public view returns (uint256) {
        return (_lastDebt * _indexIncrease(block.timestamp - blockLastIRTimestamp)) / RAY;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USERS VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function positionDebt(address account) public view returns (uint256) {
        uint256 newDebtIndex = debtIndex + _indexIncrease(block.timestamp - blockLastIRTimestamp);
        return _positionDebt(account, newDebtIndex);
    }

    function _positionDebt(address account, uint256 newDebtIndex) internal view returns (uint256) {
        return positionDebtIndex[account].mulDiv(newDebtIndex, RAY, Math.Rounding.Floor);
    }
}

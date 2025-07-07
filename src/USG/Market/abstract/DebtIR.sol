// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// @title DebtIR - Computes debts for a market
/// @notice Abstract contract to track debt issuance and bad debt
/// @dev Inherits access control (LightOwnable) and reentrancy protection
abstract contract DebtIR is LightOwnable, IDebtIR, ReentrancyGuardTransient {
    /// @notice Precision factor (10^27)
    uint256 public constant RAY = 1e27;

    /// @notice Contract that calculates and updates interest rate and debt indexes
    IIRCalculator public irCalculator;

    /// @notice The USG token contract
    IUSG public USG;

    /// @notice Maximum allowable total debt in the market (in USG units)
    uint256 public maxMarketDebt;

    /// @notice Minimum loan size allowed, used to ensure economic viability of liquidations (especially on L1)
    uint256 public minimumLoan;

    /// @notice Total amount of bad debt in the system (unrecoverable or defaulted loans)
    uint256 public badDebt;

    /// @notice Aggregate of all user debt shares
    uint256 public totalDebtShares;

    /// @notice Mapping of user addresses to their debt shares
    mapping(address => uint256) public userDebtShares;

    /// @notice Error raised when attempting to repay more bad debt than exists
    error RepayMoreThanBadDebt();
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Sets a new maximum market debt
     * @dev Callable only by the DAO governance
     * @param _maxMarketDebt The new maximum debt allowed in the system
     */
    function setMaxMarketDebt(uint256 _maxMarketDebt) external onlyOwner {
        maxMarketDebt = _maxMarketDebt;
    }

    /**
     * @notice Sets the minimum loan size a user can borrow
     * @dev Used to discourage small loans that are unprofitable to liquidate
     * @param _minimumLoan The new minimum loan size in USG
     */
    function setMinimumLoan(uint256 _minimumLoan) external onlyOwner {
        minimumLoan = _minimumLoan;
    }

    /**
     * @notice Allows anyone to repay bad debt by burning USG
     * @dev Burns `amount` of USG from the sender, reducing the global bad debt
     * @param amount The amount of USG to repay from bad debt
     */
    function repayBadDebt(uint256 amount) external nonReentrant {
        uint256 _badDebt = badDebt;
        require(amount <= _badDebt, RepayMoreThanBadDebt());
        badDebt = _badDebt - amount;
        USG.burnFrom(msg.sender, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Updates debt shares for a user and the market total
     * @dev Must be called whenever borrowing or repaying to sync the internal accounting
     * @param account Address of the user
     * @param newUserDebtShare New debt share for the user
     * @param newTotalDebtShares New total market debt shares
     */
    function _updateDebts(address account, uint256 newUserDebtShare, uint256 newTotalDebtShares) internal {
        userDebtShares[account] = newUserDebtShare;
        totalDebtShares = newTotalDebtShares;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL VIEWS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Internal pure helper to compute total debt
     * @param _badDebt Current bad debt
     * @param _totalDebtShares Current total shares
     * @param newDebtIndex Current debt index (with interest)
     * @return Calculated total debt
     */
    function _totalDebt(uint256 _badDebt, uint256 _totalDebtShares, uint256 newDebtIndex) internal pure returns (uint256) {
        return _badDebt + (_totalDebtShares * newDebtIndex) / RAY;
    }

    /**
     * @notice Internal helper to compute user's debt from shares and index
     * @param _userDebtShares User's debt shares
     * @param newDebtIndex Current debt index (with interest)
     * @return User's actual USG debt
     */
    function _userDebt(uint256 _userDebtShares, uint256 newDebtIndex) internal pure returns (uint256) {
        return (_userDebtShares * newDebtIndex) / RAY;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PUBLIC VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Returns the current total debt in USG (including interest)
     * @dev Applies the interest index to total debt shares and adds bad debt
     * @return Total outstanding system debt in USG
     */
    function totalDebt() public view returns (uint256) {
        return _totalDebt(badDebt, totalDebtShares, irCalculator.newDebtIndex(address(this)));
    }

    /**
     * @notice Returns the total debt of a user (including accrued interest)
     * @dev Applies current debt index to user's stored shares
     * @param account User address
     * @return The total debt the user owes in USG
     */
    function userDebt(address account) public view returns (uint256) {
        return _userDebt(userDebtShares[account], irCalculator.newDebtIndex(address(this)));
    }

    /**
     * @notice Calculates the interest accumulated since last checkpoint
     * @return Interest amount in USG accrued but not yet reflected in totalDebtShares
     */
    function pendingInterests() external view returns (uint256) {
        return (totalDebtShares * irCalculator.indexDelta(address(this))) / RAY;
    }
}

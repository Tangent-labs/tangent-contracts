// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
import {LightReentrancyGuardTransient} from "../../Utilities/abstract/LightReentrancyGuardTransient.sol";

/// @title DebtIR - Computes debts for a market
/// @notice Abstract contract to track debt issuance and bad debt
/// @dev Inherits access control (LightOwnable) and reentrancy protection
abstract contract DebtIR is LightOwnable, IDebtIR, LightReentrancyGuardTransient {
    /// @notice Precision factor (10^27)
    uint256 public constant RAY = 1e27;

    /// @notice Contract that calculates and updates interest rate and debt indexes
    IIRCalculator public irCalculator;

    /// @notice The USG token contract
    IUSG public usg;

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
    error TotalDebtTooHigh();
    error UserDebtTooLow();
    error UserDebtZero();
    error ZeroDebtAmount();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    event SetMaxMarketDebt(uint256 newMaxMarketDebt);
    event SetMinimumLoan(uint256 newMinimumLoan);
    event RepayBadDebt(address user, uint256 badDebtRepaid);

    /**
     * @notice Sets a new maximum market debt
     * @dev Callable only by the DAO governance
     * @param _maxMarketDebt The new maximum debt allowed in the system
     */
    function setMaxMarketDebt(uint256 _maxMarketDebt) external onlyOwner {
        maxMarketDebt = _maxMarketDebt;
        emit SetMaxMarketDebt(_maxMarketDebt);
    }

    /**
     * @notice Sets the minimum loan size a user can borrow
     * @dev Used to discourage small loans that are unprofitable to liquidate
     * @param _minimumLoan The new minimum loan size in USG
     */
    function setMinimumLoan(uint256 _minimumLoan) external onlyOwner {
        minimumLoan = _minimumLoan;
        emit SetMinimumLoan(_minimumLoan);
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
        _burnUSG(msg.sender, amount);

        emit RepayBadDebt(msg.sender, amount);
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
        return _badDebt + _convertToAmount(_totalDebtShares, newDebtIndex);
    }

    /**
     * @dev   Convert a debt amount to a debt shares
     * @param debt  Debt amount
     * @param index Debt index of the market
     * @return Debt shares
     */
    function _convertToShares(uint256 debt, uint256 index) internal pure returns (uint256) {
        return Math.mulDiv(debt, RAY, index, Math.Rounding.Ceil);
    }

    /**
     * @dev   Convert a debt shares to a debt amount
     * @param debtShares  Debt shares
     * @param index       Debt index of the market
     * @return Debt amount
     */
    function _convertToAmount(uint256 debtShares, uint256 index) internal pure returns (uint256) {
        return Math.mulDiv(debtShares, index, RAY, Math.Rounding.Floor);
    }

    /**
     * @dev   Multiply two numbers `a` and `b`then divide the result by `d`
     * @param a  First number of the product
     * @param b  Second number of the product
     * @param d  Denominator
     * @return Result of the operation
     */
    function _mulDiv(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        return (a * b) / d;
    }

    /**
     * @dev   Burns some USG from an account
     * @param account Account from where to burn USG
     * @param amount  Amount of USG to burn
     */
    function _burnUSG(address account, uint256 amount) internal {
        usg.burnFrom(account, amount);
    }

    /**
     * @dev   Mints some USG on an amount
     * @param _usg    USG token
     * @param account Account to mint USG on
     * @param amount  Amount of USG to mint
     */
    function _mintUSG(IUSG _usg, address account, uint256 amount) internal {
        _usg.mint(account, amount);
    }

    /**
     * @dev  Computes and update the debtIndex on the IRCalculator and returns the new one
     * @return The new debt index of the market
     */
    function _checkpointIR() internal returns (uint256) {
        return irCalculator.checkpointIR(address(this));
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
        return _convertToAmount(userDebtShares[account], irCalculator.newDebtIndex(address(this)));
    }

    /**
     * @notice Calculates the interest accumulated since last checkpoint
     * @return Interest amount in USG accrued but not yet reflected in totalDebtShares
     */
    function pendingInterests() external view returns (uint256) {
        return _convertToAmount(totalDebtShares, irCalculator.indexDelta(address(this)));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VERIFIERS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Fails if the new amount of total debt is over the maximum debt of the market
     * @param _badDebt    Collat amount to deposit or withdraw
     * @param totalShares Collat amount to deposit or withdraw
     * @param debtIndex   Collat amount to deposit or withdraw

     */
    function _verifyDebtCap(uint256 _badDebt, uint256 totalShares, uint256 debtIndex) internal view {
        require(_totalDebt(_badDebt, totalShares, debtIndex) <= maxMarketDebt, TotalDebtTooHigh());
    }

    /**
     * @dev Fails if the amount of debt for an account is under the minimum loan allowed
     * @param debt  Debt amount of the user
     */
    function _verifyMinimumDebt(uint256 debt) internal view {
        require(debt >= minimumLoan, UserDebtTooLow());
    }

    /**
     * @dev Fails if the amount of debt in input is null
     * @param debt  Debt amount to borrow or repay
     */
    function _verifyDebtInputNotZero(uint256 debt) internal pure {
        require(debt != 0, ZeroDebtAmount());
    }
}

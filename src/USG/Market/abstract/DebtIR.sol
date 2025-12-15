// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
import {LightReentrancyGuardTransient} from "../../Utilities/abstract/LightReentrancyGuardTransient.sol";

/// @title DebtIR - Computes debts for a market
/// @author Tangent Finance
/// @notice Abstract contract to track debt issuance and bad debt
/// @dev Inherits access control (LightOwnable) and reentrancy protection
abstract contract DebtIR is LightOwnable, IDebtIR, LightReentrancyGuardTransient {
    /// @notice Precision factor (10^27)
    uint256 constant RAY = 1e27;

    /// @notice Contract that calculates and updates interest rate and debt indexes
    IIRCalculator public irCalculator;

    /// @notice The USG token contract
    IUSG usg;

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
     * @param account            Address of the user
     * @param newUserDebtShare   New debt share for the user
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
     * @dev   Convert a debt amount to a debt shares
     * @param  debt  Debt amount
     * @param  index Debt index of the market
     * @return debtShares
     */
    function _convertToShares(uint256 debt, uint256 index, Math.Rounding roundingType) internal pure returns (uint256) {
        return Math.mulDiv(debt, RAY, index, roundingType);
    }

    /**
     * @dev   Convert a debt shares to a debt amount
     * @param  debtShares  Debt shares
     * @param  index       Debt index of the market
     * @return debtAmount
     */
    function _convertToAmount(uint256 debtShares, uint256 index, Math.Rounding roundingType) internal pure returns (uint256) {
        return Math.mulDiv(debtShares, index, RAY, roundingType);
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
        usg.burnDebt(account, amount);
    }

    /**
     * @dev   Mints an USG `amount` on an `account`
     * @param _usg    USG token
     * @param account Account to mint USG on
     * @param amount  Amount of USG to mint
     */
    function _mintUSG(IUSG _usg, address account, uint256 amount) internal {
        _usg.mintDebt(account, amount);
    }

    /**
     * @dev  Computes and update the debtIndex on the IRCalculator and returns the new one
     * @return The new debt index of the market
     */
    function _checkpointIR() internal returns (uint256) {
        return irCalculator.checkpointIR(address(this));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VERIFIERS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Fails if the new amount of total debt is over the maximum debt of the market
     * @param totalShares Total debt shares on the market
     * @param debtIndex   Debt index of the market

     */
    function _verifyDebtCap(uint256 totalShares, uint256 debtIndex) internal view {
        require(badDebt + _convertToAmount(totalShares, debtIndex, Math.Rounding.Ceil) <= maxMarketDebt, TotalDebtTooHigh());
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

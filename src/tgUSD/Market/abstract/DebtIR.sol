// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ITgUSD} from "../../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {LightOwnable} from "../../Utilities/LightOwnable.sol";

import "forge-std/console.sol";

/// @notice
abstract contract DebtIR is LightOwnable, IDebtIR {
    uint256 public constant RAY = 1e27; // Facteur de précision ray (1 * 10^27)

    /// @notice Computes the interest rate and the cut of rewards.
    IIRCalculator public irCalculator;
    /// @notice tgUSD is the StableCoin to borrow against the collatToken.
    ITgUSD public tgUSD;
    /// @notice Global debt index. Represents the accumulation of the interest rate among time.
    uint256 public debtIndex;

    /// @notice Maximum debt of the market
    uint256 public maxMarketDebt;
    /// @notice Loan minimum in tgUSD. We need it higher on L1 to keep liquidations profitable for liquidators
    uint256 public minimumLoan;
    /// @notice Bad debt amount in tgUSD of the market.
    uint256 public badDebt;

    /// @notice Last total debt of the market.
    uint256 public totalDebtShares;
    /// @notice Debt in amount of tgUSD per user.
    mapping(address => uint256) public userDebtShares;

    error NotIRMinter();
    error RepayMoreThanBadDebt();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Updates the maximum debt in tgUSD of the market.
     *  @dev    Function callable only by the DAO
     *  @param  _maxMarketDebt New maximum debt of the market
     */
    function setMaxMarketDebt(uint256 _maxMarketDebt) external onlyOwner {
        maxMarketDebt = _maxMarketDebt;
    }

    /**
     *  @notice Updates the value in tgUSD of the minimum loan that can be openned by a user.
     *  @dev    Function callable only by the DAO
     *  @param  _minimumLoan New minimum debt.
     */
    function setMinimumLoan(uint256 _minimumLoan) external onlyOwner {
        minimumLoan = _minimumLoan;
    }

    /**
     *  @notice Repays an amount of tgUSD to cover some bad debt.
     *  @dev    Callable by anyone
     *  @param  amount Amount of tgUSD to burn to cover the bad debt
     */
    function repayBadDebt(uint256 amount) external {
        uint256 _badDebt = badDebt;
        require(amount <= _badDebt, RepayMoreThanBadDebt());
        badDebt = _badDebt - amount;
        tgUSD.burnFrom(msg.sender, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice  Updates the Total debt and the User debt
     *  @dev     Called during all function modifying the debt of a user such as borrow and repay.
     *  @param account           Address of the account to update
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebtShares      New total debt of the market
     *
     */
    function _updateDebts(address account, uint256 newDebtIndex, uint256 newUserDebtShare, uint256 newTotalDebtShares) internal {
        // Recompute the new debt index of the user based on his new debt recomputed with interests and the new debtIndex
        userDebtShares[account] = newUserDebtShare;

        // Update the totalDebt
        totalDebtShares = newTotalDebtShares;

        debtIndex = newDebtIndex;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEBT & IR CHECKPOINTS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function checkpointIR() external {
        (uint256 newDebtIndex, ) = _checkpointIR();
        debtIndex = newDebtIndex;
    }

    /**
     *  @notice Computes and returns the new debt index regarding interests generated allowing to readjust the total debt of the market
     *          If some interests are generated, it increments the value in tgUSD to be able to mint them later.
     *  @dev    Example :
     *                    - On a market with 2M debt with 10% interests on 6 month
     *                    - IndexIncrease = 0.1 * 6 month / 1 year = 5%
     *                    - Interest Generated = 2M * 5% = 100 000
     */
    function _checkpointIR() internal returns (uint256, uint256) {
        uint256 _debtIndex = debtIndex;
        uint256 _totalDebtShares = totalDebtShares;

        uint256 newDebtIndex = irCalculator.checkpointIR(_debtIndex);

        uint256 indexIncrease = newDebtIndex - _debtIndex;

        if (indexIncrease != 0) {
            tgUSD.increaseMintableInterests((_totalDebtShares * indexIncrease) / RAY);
        }

        return (newDebtIndex, _totalDebtShares);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        GLOBAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     *  @notice  Returns the total debt of the market
     *  @dev     Takes the last registered debt and applies it the IR accumulated since last checkpoint.
     */
    function totalDebt() public view returns (uint256) {
        return badDebt + (totalDebtShares * irCalculator.newDebtIndex(address(this), debtIndex)) / RAY;
    }

    /**
     *  @notice  Returns IR generated since the last checkpoint
     */
    function pendingInterests() external view returns (uint256) {
        uint256 _debtIndex = debtIndex;
        return _pendingInterests(totalDebtShares, irCalculator.newDebtIndex(address(this), _debtIndex) - _debtIndex);
    }

    function _pendingInterests(uint256 _totalDebtShares, uint256 indexIncrease) internal pure returns (uint256) {
        return (_totalDebtShares * indexIncrease) / RAY;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USERS VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice  Returns the debt of a position
     *  @dev     Takes the last registered debt index of the position and applies it the IR accumulated since last checkpoint.
     *  @param   account Address of the position to check the debt on
     */
    function positionDebt(address account) public view returns (uint256) {
        return _positionDebt(userDebtShares[account], irCalculator.newDebtIndex(address(this), debtIndex));
    }

    function _positionDebt(uint256 _userDebtShares, uint256 newDebtIndex) internal pure returns (uint256) {
        return (_userDebtShares * newDebtIndex) / RAY;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ItgUSD} from "../../interfaces/internals/tgUSD/ItgUSD.sol";

import "forge-std/console.sol";

/// @notice
abstract contract DebtIR is Ownable {
    using Math for uint256;
    uint256 public constant RAY = 1e27; // Facteur de précision ray (1 * 10^27)

    /// @dev tgUSD is the StableCoin to borrow against the collatToken.
    ItgUSD public tgUSD;
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

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        IR MINTER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice  Updates the Total debt and the User debt
     *  @dev     Called during all function modifying the debt of a user such as borrow and repay.
     *  @param account           Address of the account to update
     *  @param newUserDebt       New debt of the account
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     *
     */
    function _updateDebts(address account, uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        // Recompute the new debt index of the user based on his new debt recomputed with interests and the new debtIndex
        positionDebtIndex[account] = newUserDebt.mulDiv(RAY, newDebtIndex, Math.Rounding.Floor);

        _updateGlobalDebt(newDebtIndex, newTotalDebt);
    }

    /**
     *  @notice  Updates the Total debt.
     *  @dev     Called each time an interaction is done with this contract.
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     *
     */
    function _updateGlobalDebt(uint256 newDebtIndex, uint256 newTotalDebt) internal {
        // Update the debtIndex
        debtIndex = newDebtIndex;

        // Update the last block timestamp with the actual
        blockLastIRTimestamp = block.timestamp;

        // Update the totalDebt
        lastDebt = newTotalDebt;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEBT & IR CHECKPOINTS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice  Computes the % of interests to apply on the last total debt since the last checkpoint.
     *  @dev     This function is usefull to readjust the total debt of the market regarding the last IR.
     *           Example :
     *                     - On a market with 1M debt with 10% interests on 1 month
     *                     - IndexIncrease = 0.1 * 1 month / 1 year = 0.833%
     *  @param   timeDelta  Time elapsed in second since the last interaction with the contract
     */
    function _indexIncrease(uint256 timeDelta) internal view returns (uint256) {
        uint256 _lastIr = lastIR;

        if (_lastIr != 0) {
            return _lastIr.mulDiv(timeDelta, 36500 days, Math.Rounding.Floor);
        } else {
            return 0;
        }
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
        // Time elapsed between now and the last checkpoint
        uint256 timeDelta = block.timestamp - blockLastIRTimestamp;
        uint256 newTotalDebt = lastDebt;
        uint256 newDebtIndex = debtIndex;

        if (timeDelta != 0) {
            uint256 indexIncrease = _indexIncrease(timeDelta);
            newDebtIndex += indexIncrease;

            uint256 interestsGenerated = (newTotalDebt * indexIncrease) / RAY;

            tgUSD.increaseMintableInterests(interestsGenerated);

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

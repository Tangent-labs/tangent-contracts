// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {ILiquidatorProxy} from "../../../interfaces/internals/tgUSD/ILiquidatorProxy.sol";

import {DebtIR} from "./DebtIR.sol";

import "forge-std/console.sol";

/// @notice
abstract contract Collateral is DebtIR, ICollateral {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;

    /// @notice Collateral asset of the market
    IERC20Metadata public collatToken;
    /// @notice Contract allowing to retrieve the price in dollar of the collateral.
    IPriceOracle public collatOracle;
    /// @notice Liquidation proxy
    ILiquidatorProxy public liquidatorProxy;

    /// @notice Maxium Loan to Value of the market in %.
    uint256 public maxLTV;
    /// @notice Liquidation threshold of the market in %.
    uint256 public liquidationThreshold;

    /// @notice Total amount of collateral on the market
    uint256 public totalCollateral;

    /// @notice Amount of collateral deposited by a user.
    mapping(address => uint256) public collateralBalances;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Updates the Oracle address allowing to price the collateral.
     *  @dev    Function callable only by the DAO
     *  @param _collatOracle Address of the new oracle.
     */
    function setCollatOracle(IPriceOracle _collatOracle) external onlyOwner {
        collatOracle = _collatOracle;
    }

    /**
     *  @notice Updates the maximum Loan to Value allowed on the market.
     *  @dev    Function callable only by the DAO
     *  @param _maxLTV New maxLTV percentage
     */
    function setMaxLTV(uint256 _maxLTV) external onlyOwner {
        maxLTV = _maxLTV;
    }

    /**
     *  @notice Updates the liquidation threshold of the market.
     *  @dev    Function callable only by the DAO
     *  @param _liquidationThreshold New maximum liquidation threshold
     */
    function setLiquidationThreshold(uint256 _liquidationThreshold) external onlyOwner {
        liquidationThreshold = _liquidationThreshold;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @dev  Updates in the storage the Total debt, User debt and Collateral owned by an account
     *        Called during depositAndBorrow, withdrawAndReway, liquidate and selfLiquidate functions.
     *  @param account           Address of the account to update
     *  @param newCollatBalance  New collateral balance of account
     *  @param newUserDebt       New debt of the account
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     */
    function _updateCollatAndDebts(address account, uint256 newCollatBalance, uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        // Updates the collateral owned by the account.
        collateralBalances[account] = newCollatBalance;

        // Updates global and user debt
        _updateDebts(account, newUserDebt, newDebtIndex, newTotalDebt);
    }

    /**
     *  @dev  Updates in the storage the Total debt and Collateral owned by an account
     *        Called during simple deposit and withdraw.
     *  @param account           Address of the account to update
     *  @param newCollatBalance  New collateral balance of account
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     */
    function _updateCollatAndGlobalDebt(address account, uint256 newCollatBalance, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        // Updates the collateral owned by the account.
        collateralBalances[account] = newCollatBalance;

        // Updates global debt
        _updateGlobalDebt(newDebtIndex, newTotalDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Returns the maximum of tgUSD borrowable on the market per an account.
     *  @param account  Address of the account to check the maximum borrowable
     */
    function maxBorrowable(address account) external view returns (uint256) {
        return _maxBorrowable(account);
    }

    function _maxBorrowable(uint256 collatAmount) internal view returns (uint256) {
        return (maxLTV * _positionValue(collatAmount)) / DENOMINATOR;
    }

    function _collateralPrice() internal view returns (uint256) {
        return collatOracle.latestAnswer();
    }

    function _positionValue(uint256 collatAmount) internal view returns (uint256) {
        return (collatAmount * _collateralPrice()) / 1 ether;
    }

    function _healthRatio(uint256 userDebt, uint256 collateralBalance) internal view returns (uint256) {
        if (userDebt != 0) {
            return (collateralBalance * _collateralPrice() * liquidationThreshold) / (userDebt * DENOMINATOR);
        }
        return MAX_UINT;
    }
    function _maxBorrowable(address account) internal view returns (uint256) {
        return (maxLTV * _positionValue(account)) / DENOMINATOR;
    }

    function _positionValue(address account) internal view returns (uint256) {
        return (collateralBalances[account] * _collateralPrice()) / 1 ether;
    }

    function positionValue(address account) external view returns (uint256) {
        return (collateralBalances[account] * _collateralPrice()) / 1 ether;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USERS VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function healthRatio(address account) public view returns (uint256) {
        return _healthRatio(positionDebt(account), collateralBalances[account]);
    }

    function liquidationPrice(address account) public view returns (uint256) {
        return ((positionDebt(account) * DENOMINATOR) * 1e18) / (collateralBalances[account] * liquidationThreshold);
    }
}

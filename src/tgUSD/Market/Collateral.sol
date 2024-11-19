// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {DebtIR, Ownable} from "./DebtIR.sol";

import "forge-std/console.sol";

/// @notice
abstract contract Collateral is DebtIR {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;

    /// @dev Collateral token of the MarketCore.
    IERC20Metadata public collatToken;
    /// @dev Contract allowing to retrieve the price in dollar of the collateral.
    IPriceOracle public collatOracle;

    /// @dev Maxium Loan to Value of the market in %
    uint256 public maxLTV;
    /// @dev Liquidation threshold of the market in %.
    uint256 public liquidationThreshold;

    /// @dev Amount of collateral deposited by a user.
    mapping(address => uint256) public collateralBalances;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function setCollatOracle(IPriceOracle _collatOracle) external onlyOwner {
        collatOracle = _collatOracle;
    }

    function setMaxLTV(uint256 _maxLTV) external onlyOwner {
        maxLTV = _maxLTV;
    }
    function setLiquidationThreshold(uint256 _liquidationThreshold) external onlyOwner {
        liquidationThreshold = _liquidationThreshold;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _updateCollatAndDebts(address account, uint256 newCollatBalance, uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        /// @dev Increase collateral deposited by the user
        collateralBalances[account] = newCollatBalance;

        /// @dev Modify
        _updateDebts(account, newUserDebt, newDebtIndex, newTotalDebt);
    }

    function _updateCollatAndGlobalDebt(address account, uint256 newCollatBalance, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        /// @dev Increase collateral deposited by the user
        collateralBalances[account] = newCollatBalance;

        /// @dev Modify
        _updateGlobalDebt(newDebtIndex, newTotalDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        INTERNAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function maxBorrowable(address account) external view returns (uint256) {
        return _maxBorrowable(account);
    }

    function _maxBorrowable(uint256 collatAmount) internal view returns (uint256) {
        return (maxLTV * _collateralValue(collatAmount)) / DENOMINATOR;
    }

    function _collateralPrice() internal view returns (uint256) {
        return collatOracle.latestAnswer();
    }

    function _collateralValue(uint256 collatAmount) internal view returns (uint256) {
        return (collatAmount * _collateralPrice()) / 1 ether;
    }

    function _healthRatio(uint256 userDebt, uint256 collateralBalance) internal view returns (uint256) {
        if (userDebt != 0) {
            return (collateralBalance * _collateralPrice() * liquidationThreshold) / (userDebt * DENOMINATOR);
        }
        return MAX_UINT;
    }
    function _maxBorrowable(address account) internal view returns (uint256) {
        return (maxLTV * _collateralValue(account)) / DENOMINATOR;
    }

    function _collateralValue(address account) internal view returns (uint256) {
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

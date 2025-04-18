// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {ILiquidatorProxy} from "../../../interfaces/internals/tgUSD/ILiquidatorProxy.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";

import {DebtIR} from "./DebtIR.sol";

/// @notice
abstract contract Collateral is DebtIR, ICollateral {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;

    /// @notice Collateral asset of the market
    IERC20Metadata public collatToken;
    /// @notice Contract allowing to retrieve the price in dollar of the collateral.
    IPriceOracle public collatOracle;

    IRewardAccumulator public rewardAccumulator;

    /// @notice Maxium Loan to Value of the market in %.
    uint256 public maxLTV;
    /// @notice Liquidation threshold of the market in %.
    uint256 public liquidationThreshold;

    /// @notice Total amount of collateral on the market
    uint256 public totalCollateral;

    /// @notice Amount of collateral deposited by a user.
    mapping(address => uint256) public collateralBalances;

    error NewLiquidationThresholdTooHigh();
    error NewLiquidationThresholdTooLow();

    error NewMaxLTVTooHigh();
    error NewMaxLTVTooLow();

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
        // Can't be less than the liquidation threshold
        require(_maxLTV < liquidationThreshold, NewLiquidationThresholdTooHigh());
        maxLTV = _maxLTV;
    }

    /**
     *  @notice Updates the liquidation threshold of the market.
     *  @dev    Function callable only by the DAO
     *  @param _liquidationThreshold New maximum liquidation threshold
     */
    function setLiquidationThreshold(uint256 _liquidationThreshold) external onlyOwner {
        // Can't be more than 100%
        require(_liquidationThreshold < DENOMINATOR, NewLiquidationThresholdTooHigh());
        // Can't be less than the maxLTV
        require(_liquidationThreshold > maxLTV, NewLiquidationThresholdTooLow());
        liquidationThreshold = _liquidationThreshold;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _updateCollateral(address account, uint256 newCollatBalance, uint256 newTotalCollat) internal {
        // Updates the total collateral on the market.
        totalCollateral = newTotalCollat;
        // Updates the collateral owned by the account.
        collateralBalances[account] = newCollatBalance;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PUBLIC VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Returns the maximum of tgUSD borrowable on the market per an account.
     *  @param account  Address of the account to check the maximum borrowable
     */
    function maxBorrowable(address account) external view returns (uint256) {
        return _maxBorrowable(account);
    }

    /// @notice Computes and returns the value in $ of the collateral of an account.
    /// @param account Account to check the value of the collateral
    /// @return The value in $ and base 1e18 of the collateral of a position
    function positionValue(address account) external view returns (uint256) {
        return _positionValue(account);
    }

    function healthRatio(address account) public view returns (uint256) {
        return _healthRatio(userDebt(account), collateralBalances[account]);
    }

    function liquidationPrice(address account) public view returns (uint256) {
        return ((userDebt(account) * DENOMINATOR) * 1e18) / (collateralBalances[account] * liquidationThreshold);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        INTERNAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _maxBorrowable(uint256 collatAmount) internal view returns (uint256) {
        return (maxLTV * _positionValue(collatAmount)) / DENOMINATOR;
    }

    function _collateralPrice() internal view returns (uint256) {
        return collatOracle.latestAnswer();
    }

    function _positionValue(uint256 collatAmount) internal view returns (uint256) {
        return (collatAmount * _collateralPrice()) / 1 ether;
    }

    /// @notice Computes an returns a health ratio giving a debt and a collateral amount.
    /// @param userDebt_          Debt of the position
    /// @param collateralBalance  Amount of collateral
    /// @return The health ratio in base 1e18
    function _healthRatio(uint256 userDebt_, uint256 collateralBalance) internal view returns (uint256) {
        if (userDebt_ != 0) {
            return (collateralBalance * _collateralPrice() * liquidationThreshold) / (userDebt_ * DENOMINATOR);
        }
        return MAX_UINT;
    }

    /// @notice Computes and returns the maximum amount of tgUSD borrowable for an account givin its collateral value.
    /// @param account Account to check the maximum borrowable
    /// @return The maximum borrowable amount of tgUSD
    function _maxBorrowable(address account) internal view returns (uint256) {
        return (maxLTV * _positionValue(account)) / DENOMINATOR;
    }

    /// @notice Computes and returns the value in $ of the collateral of an account.
    /// @param account Account to check the value of the collateral
    /// @return The value in $ and base 1e18 of the collateral of a position
    function _positionValue(address account) internal view returns (uint256) {
        return (collateralBalances[account] * _collateralPrice()) / 1 ether;
    }

    function getBalanceAndTotalCollateral(address account) external view returns (uint256, uint256) {
        return (collateralBalances[account], totalCollateral);
    }
}

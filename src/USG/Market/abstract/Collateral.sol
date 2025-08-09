// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";

import {DebtIR} from "./DebtIR.sol";

/// @title Collateral
/// @notice Abstract contract that defines collateral management logic
abstract contract Collateral is DebtIR, ICollateral {
    /// @dev Maximum uint256 value
    uint256 constant MAX_UINT = uint256(int256(-1));

    /// @notice Denominator used for percentage calculations (e.g. 100% = 100_000)
    uint256 public constant DENOMINATOR = 100_000;

    /// @notice The amount of decimals of the collateral
    uint256 public collatDecimals;

    /// @notice Collateral token
    IERC20Metadata public collatToken;

    /// @notice Oracle for retrieving collateral price in USD (1e18 precision)
    IPriceOracle public collatOracle;

    /// @notice Contract to track or distribute collateral rewards
    IRewardAccumulator public rewardAccumulator;

    /// @notice Maximum Loan-to-Value ratio (e.g., 75% = 75,000)
    uint256 public maxLTV;

    /// @notice Threshold where liquidation begins (must be > maxLTV)
    uint256 public liquidationThreshold;

    /// @notice Liquidation fee charged in USG (e.g., 5% = 5,000)
    uint256 public liquidationFee;

    /// @notice Total collateral deposited across all users
    uint256 public totalCollateral;

    /// @notice Mapping of user address to their collateral balance
    mapping(address => uint256) public collateralBalances;

    // Error declarations for specific failure conditions
    error MaxLTVBiggerThanLiquidationThreshold();
    error LiquidationThresholdTooHigh();
    error LiquidationThresholdTooLow();
    error LiquidationFeeTooHigh();
    error MaxLTVTooHigh();
    error MaxLTVTooLow();
    error OverMaxLTV();
    error ZeroCollatAmount();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Updates the oracle used to fetch collateral price
     * @dev Callable only by contract owner (DAO or governance)
     * @param _collatOracle Address of the new oracle contract
     */
    function setCollatOracle(IPriceOracle _collatOracle) external onlyOwner {
        collatOracle = _collatOracle;
    }

    /**
     * @notice Updates the max LTV (Loan to Value) ratio
     * @dev Must be less than the current liquidation threshold
     * @param _maxLTV New maxLTV value (e.g., 75,000 for 75%)
     */
    function setMaxLTV(uint256 _maxLTV) external onlyOwner {
        require(_maxLTV < liquidationThreshold, MaxLTVBiggerThanLiquidationThreshold());
        maxLTV = _maxLTV;
    }

    /**
     * @notice Updates the liquidation threshold
     * @dev Must be between maxLTV and 100% (DENOMINATOR)
     * @param _liquidationThreshold New liquidation threshold value
     */
    function setLiquidationThreshold(uint256 _liquidationThreshold) external onlyOwner {
        require(_liquidationThreshold < DENOMINATOR, LiquidationThresholdTooHigh());
        require(_liquidationThreshold > maxLTV, LiquidationThresholdTooLow());
        liquidationThreshold = _liquidationThreshold;
    }

    /**
     * @notice Updates the liquidation fee
     * @dev Cannot exceed 15% (15,000)
     * @param _liquidationFee New liquidation fee in base 100,000
     */
    function setLiquidationFee(uint256 _liquidationFee) external onlyOwner {
        require(_liquidationFee < 15_000, LiquidationFeeTooHigh());
        liquidationFee = _liquidationFee;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Internal function to update a user's collateral balance and the total collateral
     * @param account The user account to update
     * @param newCollatBalance The new collateral amount for the user
     * @param newTotalCollat The new total collateral amount across all users
     */
    function _updateCollateral(address account, uint256 newCollatBalance, uint256 newTotalCollat) internal {
        totalCollateral = newTotalCollat;
        collateralBalances[account] = newCollatBalance;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PUBLIC VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Returns the maximum amount of USG a user can borrow based on their collateral
     * @param account Address of the user
     * @return Amount of USG borrowable
     */
    function maxBorrowable(address account) external view returns (uint256) {
        return _maxBorrowable(account, true);
    }

    /**
     * @notice Returns the USD value of the user's collateral
     * @param account Address of the user
     * @return Value in USD (1e18 precision)
     */
    function positionValue(address account) external view returns (uint256) {
        return _positionValue(account, true);
    }

    /**
     * @notice Computes a user's health ratio (safety of collateral vs debt)
     * @param account Address of the user
     * @return Health ratio (1e18 base); higher is safer
     */
    function healthRatio(address account) public view returns (uint256) {
        return _healthRatio(userDebt(account), collateralBalances[account], true);
    }

    /**
     * @notice Returns both user collateral balance and total system collateral
     * @param account Address of the user
     * @return balance User's collateral balance
     * @return total Total system collateral
     */
    function getBalanceAndTotalCollateral(address account) external view returns (uint256, uint256) {
        return (collateralBalances[account], totalCollateral);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        INTERNAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Computes maximum borrowable USG given a collateral amount
     * @param collatAmount Amount of collateral
     * @return Borrow limit in USG
     */
    function _maxBorrowable(uint256 collatAmount, bool isNoFailMode) internal view returns (uint256) {
        return _mulDiv(maxLTV, _positionValue(collatAmount, isNoFailMode), DENOMINATOR);
    }

    /**
     * @dev Returns the current price of 1 unit of collateral in USD (1e18 precision)
     */
    function _collateralPrice(bool isNoFailMode) internal view returns (uint256) {
        return collatOracle.latestAnswer(isNoFailMode);
    }

    /**
     * @dev Computes USD value of the given amount of collateral
     * @param collatAmount Amount of collateral
     * @return Value in USD (1e18 base)
     */
    function _positionValue(uint256 collatAmount, bool isNoFailMode) internal view returns (uint256) {
        return _mulDiv(collatAmount, _collateralPrice(isNoFailMode), 10 ** collatDecimals);
    }

    /**
     * @dev Computes health ratio for a position
     * @param userDebt_ Debt of the user
     * @param collateralBalance Amount of collateral
     * @return Health ratio (1e18 base)
     */
    function _healthRatio(uint256 userDebt_, uint256 collateralBalance, bool isNoFailMode) internal view returns (uint256) {
        if (userDebt_ != 0) {
            return (collateralBalance * 10 ** (18 - collatDecimals) * _collateralPrice(isNoFailMode) * liquidationThreshold) / (userDebt_ * DENOMINATOR);
        }
        return MAX_UINT; // Fully healthy if no debt
    }

    /**
     * @dev Internal view to calculate max borrowable USG for a user
     * @param account Address of the user
     * @return Max borrowable amount
     */
    function _maxBorrowable(address account, bool isNoFailMode) internal view returns (uint256) {
        return _mulDiv(maxLTV, _positionValue(account, isNoFailMode), DENOMINATOR);
    }

    /**
     * @dev Internal view to calculate position value in USD for a user
     * @param account Address of the user
     * @return Value in USD (1e18 base)
     */
    function _positionValue(address account, bool isNoFailMode) internal view returns (uint256) {
        return _mulDiv(collateralBalances[account], _collateralPrice(isNoFailMode), 10 ** collatDecimals);
    }

    /**
     * @dev Compare the value of an amount of collateral with an amount of debt to the maxLTV of the market
     *      and fails if it's not respected
     * @param collatAmount Amount of collateral
     * @param debt         Amount of debt
     * @param isNoFailMode If true, will fail if the oracle is stale
     */
    function _verifyMaxLTV(uint256 collatAmount, uint256 debt, bool isNoFailMode) internal view {
        require(_maxBorrowable(collatAmount, isNoFailMode) >= debt, OverMaxLTV());
    }

    /**
     * @dev Fails if the amount of collateral to deposit or withdraw is null
     * @param collatAmount Collat amount to deposit or withdraw
     */
    function _verifyCollatInputNotZero(uint256 collatAmount) internal pure {
        require(collatAmount != 0, ZeroCollatAmount());
    }
}

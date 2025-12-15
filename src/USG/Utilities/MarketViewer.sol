// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IMarketViewer} from "../../interfaces/internals/USG/IMarketViewer.sol";
import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";
import {IDebtIR} from "../../interfaces/internals/USG/IDebtIR.sol";

/// @title  MarketViewer
/// @author Tangent Finance
/// @notice Computes and return all information related to markets
contract MarketViewer is IMarketViewer {
    uint256 constant RAY = 1e27;
    uint256 constant MAX_UINT = uint256(int256(-1));

    /**
     * @notice Returns the current total debt in USG of a `market` (including interest)
     * @dev    Applies the interest index to total debt shares and adds bad debt
     * @param market Address of the market
     * @return totalDebt Debt total of the market in USG
     */
    function totalDebt(IDebtIR market) external view returns (uint256) {
        return market.badDebt() + _convertToAmount(market.totalDebtShares(), market.irCalculator().newDebtIndex(address(market)), Math.Rounding.Ceil);
    }

    /**
     * @notice Returns the debt of an user (including accrued interest)
     * @dev Applies current debt index to user's stored shares
     * @param market  Address of the market where the position is
     * @param account Address holding the debt position
     * @return userDebt Debt of the user in USG
     */
    function userDebt(IDebtIR market, address account) public view returns (uint256) {
        return _convertToAmount(market.userDebtShares(account), market.irCalculator().newDebtIndex(address(market)), Math.Rounding.Ceil);
    }

    /**
     * @notice Computes a user's health ratio (safety of collateral vs debt)
     *         Higher is safer. When HR < 1, position becomes liquidable.
     * @param market  Address of the market where the position is.
     * @param account Address holding the collateral position.
     * @return healthRatio  Health Ratio of a position (1e18 base).
     */
    function healthRatio(address market, address account) external view returns (uint256) {
        uint256 _userDebt = userDebt(IDebtIR(market), account);
        if (_userDebt != 0) {
            ICollateral marketCollat = ICollateral(market);
            // We fetch the price of the collateral
            uint256 collatPrice = marketCollat.collatOracle().latestAnswer(true);

            // We compute the health ratio following this formula :
            //      healthRatio = collatValue * liquidationThreshold / userDebt
            return
                (marketCollat.collateralBalances(account) * 10 ** (18 - marketCollat.collatDecimals()) * collatPrice * marketCollat.liquidationThreshold()) / (_userDebt * 100_000);
        }
        return MAX_UINT; // Fully healthy if no debt
    }

    /**
     * @notice Returns the USD value of the user's collateral
     * @param market  Address of the market where the position is.
     * @param account Address holding the collateral position.
     * @return positionValue Value in USD of the position (1e18 precision)
     */
    function positionValue(ICollateral market, address account) external view returns (uint256) {
        return (market.collateralBalances(account) * market.collatOracle().latestAnswer(true)) / 10 ** market.collatDecimals();
    }

    /**
     * @notice Returns the maximum amount of USG a user can borrow based on his collateral amount and LTV of the market
     * @param market  Address of the market where the position is.
     * @param account Address holding the collateral position.
     * @return maxBorrowable Max borrowable in USG of an account
     */
    function maxBorrowable(ICollateral market, address account) external view returns (uint256) {
        return (market.maxLTV() * _positionValue(market, account)) / 100_000;
    }

    /**
     * @notice Calculates the interest accumulated since last checkpoint of a market
     * @param market  Address of the market.
     * @return pendingInterests Amount in USG accrued since last checkpoint.
     */
    function pendingInterests(IDebtIR market) external view returns (uint256) {
        return _convertToAmount(market.totalDebtShares(), market.irCalculator().indexDelta(address(market)), Math.Rounding.Floor);
    }

    function _positionValue(ICollateral market, address account) internal view returns (uint256) {
        return (market.collateralBalances(account) * market.collatOracle().latestAnswer(true)) / 10 ** market.collatDecimals();
    }

    /**
     * @dev   Convert a debt shares to a debt amount
     * @param debtShares  Debt shares
     * @param index       Debt index of the market
     * @return Debt amount
     */
    function _convertToAmount(uint256 debtShares, uint256 index, Math.Rounding roundingType) internal pure returns (uint256) {
        return Math.mulDiv(debtShares, index, RAY, roundingType);
    }
}

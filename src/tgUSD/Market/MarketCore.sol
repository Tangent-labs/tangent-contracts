// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMarket, ItgUSD, IPriceOracle} from "../../interfaces/internals/tgUSD/IMarket.sol";

import {Collateral, Ownable} from "./Collateral.sol";

import "forge-std/console.sol";

/// @notice
abstract contract MarketCore is Collateral, IMarket {
    /// @dev tgUSD is the StableCoin to borrow against the collatToken.
    ItgUSD public tgUSD;
    /// @dev Contract allowing to retrieve the price in dollar of tgUSD.
    IPriceOracle public tgUSDOracle;

    error TotalDebtTooHigh();
    error PositionDebtTooHigh();
    error PositionDebtTooLow();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotLiquidablePosition();

    constructor(MarketInit memory _marketInit) Ownable(msg.sender) {
        tgUSD = _marketInit.tgUSD;
        tgUSDOracle = _marketInit.tgUSDOracle;
        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;
        irMinter = _marketInit.irMinter;

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        lastIR = 10 * RAY; // 10%
        blockLastIRTimestamp = block.timestamp;

        debtIndex = RAY;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal virtual returns (uint256, IERC20) {}

    function _deposit(address _for, uint256 amountDeposited) internal {
        /// @dev Verify that newDebt is over the minimum loan

        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        /// @dev Increase collateral deposited by the user
        _updateCollatAndGlobalDebt(_for, collateralBalances[_for] + amountDeposited, newDebtIndex, newTotalDebt);
    }

    function _transferCollateralDeposit(IERC20 _collatToken, uint256 lpDeposited, uint256 lpStaked, bool isStaked) internal virtual {}
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preWithdraw(uint256 lpToWithdraw) internal virtual {}

    function _commonWithdraw(uint256 amountToWithdraw, uint256 newDebtIndex) internal view returns (uint256) {
        require(amountToWithdraw != 0, ZeroCollatAmount());
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(newCollatAmount) >= _positionDebt(msg.sender, newDebtIndex), PositionDebtTooHigh());
        return newCollatAmount;
    }

    function _withdraw(uint256 amountToWithdraw) internal {
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        /// @dev Increase collateral deposited by the user
        _updateCollatAndGlobalDebt(msg.sender, _commonWithdraw(amountToWithdraw, newDebtIndex), newDebtIndex, newTotalDebt);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal virtual {}

    /* --------
                            BORROW 
                                                    ------ */

    function _borrow(address receiver, uint256 tgUSDToBorrow, uint256 collatAmount) internal returns (uint256, uint256, uint256) {
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        newTotalDebt += tgUSDToBorrow;

        /// @dev Cache the new value in tgUSD of the debt
        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToBorrow;

        /// @dev Verify that the new total debt is not bigger the max debt
        require(newTotalDebt <= maxMarketDebt, TotalDebtTooHigh());
        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, PositionDebtTooLow());

        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(collatAmount) >= newUserDebt, PositionDebtTooHigh());

        /// @dev Mint tgUSD to the user
        tgUSD.mint(receiver, tgUSDToBorrow);

        return (newUserDebt, newDebtIndex, newTotalDebt);
    }

    function _depositAndBorrow(uint256 amountDeposited, uint256 tgUSDToBorrow) internal {
        /// @dev Verify collat amount added > 0
        require(amountDeposited != 0, ZeroCollatAmount());

        uint256 newCollatAmount = collateralBalances[msg.sender] + amountDeposited;

        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _borrow(msg.sender, tgUSDToBorrow, newCollatAmount);

        _updateCollatAndDebts(msg.sender, newCollatAmount, newUserDebt, newDebtIndex, newTotalDebt);
    }

    /* --------
                            REPAY
                                                    ------ */

    function _repay(address account, uint256 tgUSDToRepay) internal returns (uint256, uint256, uint256) {
        require(tgUSDToRepay != 0, ZeroDebtAmount());

        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        uint256 newUserDebt;

        /// @dev Repay all case
        if (tgUSDToRepay == MAX_UINT) {
            tgUSDToRepay = _positionDebt(account, newDebtIndex);
        } else {
            /// @dev Cache the new value in tgUSD of the debt
            newUserDebt = _positionDebt(account, newDebtIndex) - tgUSDToRepay;
            /// @dev Verify that newDebt is over the minimum loan
            require(newUserDebt >= minimumLoan, PositionDebtTooLow());
        }

        /// @dev Mint tgUSD from the user
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);

        return (newUserDebt, newDebtIndex, newTotalDebt - tgUSDToRepay);
    }

    function _withdrawAndRepay(uint256 amountToWithdraw, uint256 tgUSDToRepay) internal {
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _repay(msg.sender, tgUSDToRepay);

        uint256 newCollatAmount = _commonWithdraw(amountToWithdraw, newDebtIndex);

        _updateCollatAndDebts(msg.sender, newCollatAmount, newUserDebt, newDebtIndex, newTotalDebt);
    }
}

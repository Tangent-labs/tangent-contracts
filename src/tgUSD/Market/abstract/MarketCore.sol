// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMarketCore, IPriceOracle} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";
import {IControlTower} from "../../../interfaces/internals/tgUSD/IControlTower.sol";
import {Collateral, Ownable} from "./Collateral.sol";

import "forge-std/console.sol";

/// @notice
abstract contract MarketCore is IMarketCore, Collateral {
    IControlTower public controlTower;

    error TotalDebtTooHigh();
    error PositionDebtTooHigh();
    error PositionDebtTooLow();
    error PositionDebtZero();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotLiquidablePosition();

    constructor(address _owner, MarketInit memory _marketInit) Ownable(_owner) {
        tgUSD = _marketInit.tgUSD;
        controlTower = _marketInit.controlTower;
        irCalculator = _marketInit.irCalculator;
        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;

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
        // Verify that newDebt is over the minimum loan
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        // Increase collateral balance of the position and update total debt
        _updateCollatAndGlobalDebt(_for, collateralBalances[_for] + amountDeposited, newDebtIndex, newTotalDebt);
    }

    function _transferCollateralDeposit(IERC20 _collatToken, uint256 lpDeposited) internal {
        // When caller is not one of our Zapper, sender needs to send collateral token to the market.
        // Zapper send the collateral directly on the market before calling "deposit"
        if (!controlTower.isZapper(msg.sender)) {
            // Transfer the collateral from the sender to the market
            _collatToken.transferFrom(msg.sender, address(this), lpDeposited);
        }
    }
    function _postDeposit(IERC20 _collatToken, uint256 lpStaked, bool isStaked) internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preWithdraw(uint256 lpToWithdraw) internal virtual {}

    function _getBalanceAfterWithdrawAndCheckMaxBorrowable(uint256 amountToWithdraw, uint256 newUserDebt) internal view returns (uint256) {
        // Prevent to withdraw 0 collateral from the market
        require(amountToWithdraw != 0, ZeroCollatAmount());
        // Computes the decremented collateral balance of the user after the withdraw
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        // Verify that the newDebt of the loan is not over the maximum borrrowable regarding the LTV of the position
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, PositionDebtTooHigh());
        return newCollatAmount;
    }

    function _withdraw(uint256 amountToWithdraw) internal {
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        // Increase collateral deposited by the user
        _updateCollatAndGlobalDebt(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _positionDebt(msg.sender, newDebtIndex)),
            newDebtIndex,
            newTotalDebt
        );
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal virtual {}

    /* --------
                            BORROW 
                                                    ------ */

    function _borrow(address receiver, uint256 tgUSDToBorrow, uint256 collatAmount) internal returns (uint256, uint256, uint256) {
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        newTotalDebt += tgUSDToBorrow;

        //  Cache the new value in tgUSD of the debt
        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToBorrow;

        //  Verify that the new total debt is not bigger the max debt
        require(newTotalDebt <= maxMarketDebt, TotalDebtTooHigh());
        //  Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, PositionDebtTooLow());

        // Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(collatAmount) >= newUserDebt, PositionDebtTooHigh());

        // Mint tgUSD to the receiver
        tgUSD.mint(receiver, tgUSDToBorrow);

        return (newUserDebt, newDebtIndex, newTotalDebt);
    }

    function _depositAndBorrow(uint256 amountDeposited, uint256 tgUSDToBorrow) internal {
        // Verify collat amount added > 0
        require(amountDeposited != 0, ZeroCollatAmount());

        uint256 newCollatAmount = collateralBalances[msg.sender] + amountDeposited;

        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _borrow(msg.sender, tgUSDToBorrow, newCollatAmount);

        _updateCollatAndDebts(msg.sender, newCollatAmount, newUserDebt, newDebtIndex, newTotalDebt);
    }

    /* --------
                            REPAY
                                                    ------ */

    function _repay(address account, uint256 tgUSDToRepay, address burnAddress) internal returns (uint256, uint256, uint256) {
        // Cannot repay 0 debt
        require(tgUSDToRepay != 0, ZeroDebtAmount());

        // Update interests rate, computes new debt index and total debt.
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        // Retrieve the position of the user
        uint256 newUserDebt = _positionDebt(account, newDebtIndex);
        // Cannot repay an empty position
        require(newUserDebt != 0, PositionDebtZero());

        // Repay all case
        // When IR != 0, debt of the user is increasing every block.
        // It is so complicated to provide the exact amount that a user have to repay to close his loan.
        // To cover this, any debt given in parameter that is equal or bigger than the debt will close the loan.
        if (tgUSDToRepay >= newUserDebt) {
            // User shouldn't repay more than his debt so we rearrange the amount of tgUSD to repay.
            tgUSDToRepay = newUserDebt;
            // As we are repaying all the debt, the new debt of the user is 0.
            newUserDebt = 0;
        }
        // Partial repay case
        else {
            // We are adjusting the debt of the user by decrementing the amount the user wants to repay.
            newUserDebt -= tgUSDToRepay;
            // We need to verify that the partial repay is not decreasing the debt lower than the minimum loan.
            require(newUserDebt >= minimumLoan, PositionDebtTooLow());
        }

        // Burns tgUSD from the burnAddress as a repayment of the debt
        tgUSD.burnFrom(burnAddress, tgUSDToRepay);

        return (newUserDebt, newDebtIndex, newTotalDebt - tgUSDToRepay);
    }

    function _withdrawAndRepay(uint256 amountToWithdraw, uint256 tgUSDToRepay, address caller) internal {
        // Call _repay function in order to checkpoint the total debt, computes new User debt and burn corresponding amount of tgUSD.
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _repay(caller, tgUSDToRepay, caller);

        _updateCollatAndDebts(caller, _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebt), newUserDebt, newDebtIndex, newTotalDebt);
    }
}

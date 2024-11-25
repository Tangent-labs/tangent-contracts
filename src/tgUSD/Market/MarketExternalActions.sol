// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, Ownable} from "./MarketCore.sol";

import {ILiquidator} from "../../interfaces/internals/tgUSD/ILiquidator.sol";
import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function deposit(address _for, uint256 lpDeposited, bool isStaked) external {
        (uint256 lpStaked, IERC20 _collatToken) = _preDeposit(_for, lpDeposited, isStaked);
        _deposit(_for, lpStaked);
        _transferCollateralDeposit(_collatToken, lpDeposited);
        _postDeposit(_collatToken, lpStaked, isStaked);
    }

    function depositAndBorrow(address _for, uint256 lpDeposited, uint256 debtBorrow, bool isStaked) external {
        (uint256 lpStaked, IERC20 _collatToken) = _preDeposit(_for, lpDeposited, isStaked);
        _depositAndBorrow(lpStaked, debtBorrow);
        _transferCollateralDeposit(_collatToken, lpDeposited);
        _postDeposit(_collatToken, lpStaked, isStaked);
    }

    function withdraw(uint256 lpToWithdraw) external {
        _preWithdraw(lpToWithdraw);
        _withdraw(lpToWithdraw);
        _transferCollateralWithdraw(msg.sender, lpToWithdraw);
    }

    function withdrawAndRepay(uint256 lpToWithdraw, uint256 debtRepay, address callerZapper) external {
        _preWithdraw(lpToWithdraw);
        address caller = controlTower.isZapper(msg.sender) ? callerZapper : msg.sender;
        _withdrawAndRepay(lpToWithdraw, debtRepay, caller);
        _transferCollateralWithdraw(caller, lpToWithdraw);
    }

    function borrow(address receiver, uint256 tgUSDToBorrow) external {
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _borrow(receiver, tgUSDToBorrow, collateralBalances[msg.sender]);
        _updateDebts(msg.sender, newUserDebt, newDebtIndex, newTotalDebt);
    }

    function repay(address account, uint256 tgUSDToRepay, address callerZapper) external {
        address caller = controlTower.isZapper(msg.sender) ? callerZapper : msg.sender;
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _repay(account, tgUSDToRepay, caller);
        _updateDebts(account, newUserDebt, newDebtIndex, newTotalDebt);
    }

    function liquidate(address account, uint256 tgUSDToRepay, ILiquidator liquidator) external {
        /// @dev Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();
        uint256 collatBalance = collateralBalances[account];

        uint256 userDebt = _positionDebt(account, newDebtIndex);

        require(_healthRatio(userDebt, collatBalance) < 1 ether, NotLiquidablePosition());

        uint256 remainingDebt;
        uint256 newCollatBalance;
        uint256 collatAmountToLiquidate;

        /// @dev Liquidate all
        if (tgUSDToRepay >= userDebt) {
            tgUSDToRepay = userDebt;
            collatAmountToLiquidate = collatBalance;
        }
        /// @dev Liquidate partial
        else {
            collatAmountToLiquidate = (collatBalance * tgUSDToRepay) / userDebt;
            newCollatBalance = collatBalance - collatAmountToLiquidate;
            remainingDebt = userDebt - tgUSDToRepay;
            require(remainingDebt >= minimumLoan, PositionDebtTooLow());
        }

        _updateCollatAndDebts(account, newCollatBalance, remainingDebt, newDebtIndex, newTotalDebt - tgUSDToRepay);

        _transferCollateralWithdraw(address(liquidator) != address(0) ? address(liquidator) : msg.sender, collatAmountToLiquidate);

        if (address(liquidator) != address(0)) {
            liquidator.liquidate();
        }

        tgUSD.burnFrom(msg.sender, tgUSDToRepay);
    }

    /// TODO Add self liquidate partial
    function selfLiquidate(ILiquidator liquidator) external {
        /// @dev Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();
        uint256 collatBalance = collateralBalances[msg.sender];

        uint256 userDebt = _positionDebt(msg.sender, newDebtIndex);

        _updateCollatAndDebts(msg.sender, 0, 0, newDebtIndex, newTotalDebt - userDebt);

        _transferCollateralWithdraw(address(liquidator) != address(0) ? address(liquidator) : msg.sender, collatBalance);

        if (address(liquidator) != address(0)) {
            liquidator.liquidate();
        }

        tgUSD.burnFrom(msg.sender, userDebt);
    }
}

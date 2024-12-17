// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, Ownable} from "./MarketCore.sol";

import {ILiquidator} from "../../../interfaces/internals/tgUSD/ILiquidator.sol";
import {IMarketExternalActions} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @notice Set the percentage of rewards on the rewards streamed to borrowers to send to the processor.
     * @param  _for        The collateral is deposited to this address
     * @param  lpDeposited Amount of collateral to deposit
     * @param  isStaked    Stake
     */
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
        // Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt, uint256 userDebt, uint256 collatBalance) = _preLiquidate(account);

        require(_healthRatio(userDebt, collatBalance) < 1 ether, NotLiquidablePosition());

        _liquidate(account, tgUSDToRepay, userDebt, newTotalDebt, newDebtIndex, collatBalance, liquidator);
    }

    function selfLiquidate(uint256 tgUSDToRepay, ILiquidator liquidator) external {
        // Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt, uint256 userDebt, uint256 collatBalance) = _preLiquidate(msg.sender);
        _liquidate(msg.sender, tgUSDToRepay, userDebt, newTotalDebt, newDebtIndex, collatBalance, liquidator);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, LiquidateCall} from "./MarketCore.sol";

import {IMarketExternalActions} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {IZapper} from "../../../interfaces/internals/tgUSD/IZapper.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    event Deposit(address indexed account, uint256 depositedAmount, uint256 stakedAmount, bool isZapping);
    event DepositAndBorrow(address indexed account, uint256 depositedAmount, uint256 stakedAmount, uint256 borrowedAmount, bool isZapping);

    event Withdraw(address indexed account, uint256 amount);
    event WithdrawAndRepay(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, bool isZapping);

    event Borrow(address indexed account, address receiver, uint256 amount);
    event Repay(address indexed account, address repayer, uint256 amount, bool isZapping);

    event Leverage(address indexed account, uint256 depositedAmount, uint256 collatBought, uint256 borrowedAmount);

    error DepositPaused();
    error BorrowPaused();
    error LeveragePaused();
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @notice Deposit some collateral on the market for an account.
     * @param  _for            The collateral is deposited to this address
     * @param  depositedAmount Amount of collateral to deposit
     * @param  isStaked        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function deposit(address _for, uint256 depositedAmount, bool isStaked) external {
        // Check if the deposit is paused
        require(!isDepositPaused, DepositPaused());
        bool isZapping = controlTower.isZapper(msg.sender);
        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(_for, depositedAmount, isStaked);
        _deposit(_for, stakedAmount);
        _transferCollateralDeposit(_collatToken, depositedAmount, isZapping);
        _postDeposit(_collatToken, isStaked);

        emit Deposit(_for, depositedAmount, stakedAmount, isZapping);
    }

    /**
     * @notice Deposit some collateral on the market and borrow some tgUSD.
     * @param  depositedAmount Amount of collateral to deposit
     * @param  debtBorrow      Amount of tgUSD to borrow
     * @param  isStaked        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     * @param  callerZapper    Only used on zapDepositAndBorrow. It's the address calling the zapper. Is the receiver of the tgUSD borrowed and will be marked as the staker of the collateral.
     */
    function depositAndBorrow(uint256 depositedAmount, uint256 debtBorrow, bool isStaked, address callerZapper) external {
        require(!isDepositPaused, DepositPaused());
        require(!isBorrowPaused, BorrowPaused());

        (bool isZapping, address caller) = _checkZapper(callerZapper);

        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(caller, depositedAmount, isStaked);

        _depositAndBorrow(caller, stakedAmount, debtBorrow, false);
        _transferCollateralDeposit(_collatToken, depositedAmount, isZapping);
        _postDeposit(_collatToken, isStaked);

        emit DepositAndBorrow(caller, depositedAmount, stakedAmount, debtBorrow, isZapping);
    }

    /**
     * @notice Withdraw the collateral and send it to the caller.
     * @param  withdrawAmount Amount of collateral to withdraw
     */
    function withdraw(uint256 withdrawAmount) external {
        _withdraw(withdrawAmount);
        _transferCollateralWithdraw(msg.sender, withdrawAmount);

        emit Withdraw(msg.sender, withdrawAmount);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  debtRepay      Amount of debt to repay. This amount will be burnt
     * @param  callerZapper   Only used on zapWithdrawAndRepay. It's the address calling the zapper and that will receive the collateral back & where the tgUSD will be burnt.
     */
    function withdrawAndRepay(uint256 withdrawAmount, uint256 debtRepay, address callerZapper) external {
        (bool isZapping, address caller) = _checkZapper(callerZapper);

        _withdrawAndRepay(withdrawAmount, debtRepay, caller);
        _transferCollateralWithdraw(caller, withdrawAmount);

        emit WithdrawAndRepay(caller, withdrawAmount, debtRepay, isZapping);
    }

    /**
     * @notice Borrow some tgUSD from the market
     * @param  receiver       Receiver of the tgUSD that is borrowed.
     * @param  tgUSDToBorrow  Amount of tgUSD to mint to the receiver.
     */
    function borrow(address receiver, uint256 tgUSDToBorrow) external {
        require(!isBorrowPaused, BorrowPaused());
        (uint256 newUserDebtShares, uint256 newTotalDebtShares) = _borrow(msg.sender, receiver, tgUSDToBorrow, collateralBalances[msg.sender], false);
        _updateDebts(msg.sender, newUserDebtShares, newTotalDebtShares);

        emit Borrow(msg.sender, receiver, tgUSDToBorrow);
    }

    /**
     * @notice Repay some tgUSD debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  tgUSDToRepay   Amount of tgUSD to repay
     * @param  callerZapper   Only used on zapAndRepay. It's the address calling the zapper and that will receive the tgUSD during the zapping.
     */
    function repay(address account, uint256 tgUSDToRepay, address callerZapper) external {
        (bool isZapping, address repayer) = _checkZapper(callerZapper);

        (uint256 newUserDebtShares, uint256 newTotalDebtShares) = _repay(account, tgUSDToRepay, repayer);
        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit Repay(account, repayer, tgUSDToRepay, isZapping);
    }

    function liquidate(address account, uint256 tgUSDToRepay, address liquidator, uint256 minTgUSDOut, bytes calldata liquidationCall) external updateReward(account) {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));
        uint256 _userDebtShares = userDebtShares[account];
        uint256 userDebt = _userDebt(_userDebtShares, newDebtIndex);
        uint256 collatBalance = collateralBalances[account];
        // Can liquidate only if the health ratio is below 1
        require(_healthRatio(userDebt, collatBalance) < 1 ether, NotLiquidablePosition());

        _liquidate(
            LiquidateCall({
                account: account,
                tgUSDToRepay: tgUSDToRepay,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: userDebt
            }),
            liquidator,
            minTgUSDOut,
            liquidationCall
        );
    }

    function selfLiquidate(uint256 tgUSDToRepay, address liquidator, uint256 minTgUSDOut, bytes calldata routerCall) external updateReward(msg.sender) {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));
        uint256 _userDebtShares = userDebtShares[msg.sender];

        // Checkpoint IR

        _liquidate(
            LiquidateCall({
                account: msg.sender,
                tgUSDToRepay: tgUSDToRepay,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collateralBalances[msg.sender],
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: _userDebt(_userDebtShares, newDebtIndex)
            }),
            liquidator,
            minTgUSDOut,
            routerCall
        );
    }

    function liquidateBadDebt(address account) external updateReward(account) {
        // Checkpoint IR
        (uint256 collateralBalance, uint256 _totalCollateral, uint256 _userDebtShares, uint256 _totalDebtShares, uint256 userDebt) = _preLiquidate(account);

        // Can liquidate bad debt only if the value of the collateral is below the debt
        require(_positionValue(collateralBalance) < userDebt, PositionWithoutBadDebt());

        _liquidateBadDebt(account, collateralBalance, _totalCollateral, _userDebtShares, _totalDebtShares, userDebt);
    }

    function leverage(
        uint256 collatToDeposit,
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountReceived,
        address zapper,
        bool isStaked,
        bytes calldata routerCall
    ) external payable updateReward(msg.sender) {
        require(!isDepositPaused, DepositPaused());
        require(!isBorrowPaused, BorrowPaused());
        require(!isLeveragePaused, LeveragePaused());
        // Only callable from a Zapper contract
        require(controlTower.isZapper(zapper), NotZapper(zapper));
        // Mint the tgUSD on the Zapper, ready to be exchanged through the router
        tgUSD.mint(zapper, tgUSDToFlashMint);
        // Exchange the tgUSD that has just been minted on the Zapper for the collateral of the market
        uint256 collatReceived = IZapper(zapper).zapLeverage(collatToken, minCollatAmountReceived, routerCall);

        // Computes the amount
        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(msg.sender, collatToDeposit + collatReceived, isStaked);

        if (collatToDeposit != 0) {
            // Transfer the collateral coming from the user on the market
            _transferCollateralDeposit(_collatToken, collatToDeposit, false);
        }

        // Performs same modification as in depositAndBorrow
        _depositAndBorrow(msg.sender, stakedAmount, tgUSDToFlashMint, true);

        _postDeposit(_collatToken, isStaked);

        emit Leverage(msg.sender, collatToDeposit, collatReceived, tgUSDToFlashMint);
    }
}

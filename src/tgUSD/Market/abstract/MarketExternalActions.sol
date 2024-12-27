// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, Ownable} from "./MarketCore.sol";

import {ILiquidator} from "../../../interfaces/internals/tgUSD/ILiquidator.sol";
import {IMarketExternalActions} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {IZapper} from "../../../interfaces/internals/tgUSD/IZapper.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @notice Set the percentage of rewards on the rewards streamed to borrowers to send to the processor.
     * @param  _for        The collateral is deposited to this address
     * @param  depositedAmount Amount of collateral to deposit
     * @param  isStaked    Stake
     */
    function deposit(address _for, uint256 depositedAmount, bool isStaked) external {
        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(_for, depositedAmount, isStaked);
        _deposit(_for, stakedAmount);
        _transferCollateralDeposit(_collatToken, depositedAmount, controlTower.isZapper(msg.sender));
        _postDeposit(_collatToken, stakedAmount, isStaked);
    }

    function depositAndBorrow(uint256 depositedAmount, uint256 debtBorrow, bool isStaked, address callerZapper) external {
        bool isZapping = controlTower.isZapper(msg.sender);
        callerZapper = isZapping ? callerZapper : msg.sender;

        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(callerZapper, depositedAmount, isStaked);

        _depositAndBorrow(callerZapper, stakedAmount, debtBorrow, false);
        _transferCollateralDeposit(_collatToken, depositedAmount, isZapping);
        _postDeposit(_collatToken, stakedAmount, isStaked);
    }

    function withdraw(uint256 withdrawAmount) external {
        _preWithdraw(withdrawAmount);
        _withdraw(withdrawAmount);
        _transferCollateralWithdraw(msg.sender, withdrawAmount);
    }

    function withdrawAndRepay(uint256 withdrawAmount, uint256 debtRepay, address callerZapper) external {
        _preWithdraw(withdrawAmount);
        address caller = controlTower.isZapper(msg.sender) ? callerZapper : msg.sender;
        _withdrawAndRepay(withdrawAmount, debtRepay, caller);
        _transferCollateralWithdraw(caller, withdrawAmount);
    }

    function borrow(address receiver, uint256 tgUSDToBorrow) external {
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _borrow(receiver, tgUSDToBorrow, collateralBalances[msg.sender], false);
        _updateDebts(msg.sender, newUserDebt, newDebtIndex, newTotalDebt);
    }

    function repay(address account, uint256 tgUSDToRepay, address callerZapper) external {
        callerZapper = controlTower.isZapper(msg.sender) ? callerZapper : msg.sender;
        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _repay(account, tgUSDToRepay, callerZapper);
        _updateDebts(account, newUserDebt, newDebtIndex, newTotalDebt);
    }

    function liquidate(address account, uint256 tgUSDToRepay, address liquidator, bytes calldata routerCall) external {
        // Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt, uint256 userDebt, uint256 collatBalance) = _preLiquidate(account);

        require(_healthRatio(userDebt, collatBalance) < 1 ether, NotLiquidablePosition());

        _liquidate(account, tgUSDToRepay, userDebt, newTotalDebt, newDebtIndex, collatBalance, liquidator, routerCall);
    }

    function selfLiquidate(uint256 tgUSDToRepay, address liquidator, bytes calldata routerCall) external {
        // Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt, uint256 userDebt, uint256 collatBalance) = _preLiquidate(msg.sender);
        _liquidate(msg.sender, tgUSDToRepay, userDebt, newTotalDebt, newDebtIndex, collatBalance, liquidator, routerCall);
    }

    function leverage(
        uint256 collatToDeposit,
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountReceived,
        address zapper,
        bool isStaked,
        bytes calldata routerCall
    ) external payable {
        // Only callable from a Zapper contract
        require(controlTower.isZapper(zapper), NotZapper(zapper));
        // Mint the tgUSD on the Zapper, ready to be exchanged through the router
        tgUSD.mint(zapper, tgUSDToFlashMint);
        // Exchange the tgUSD that has just been minted on the Zapper for the collateral of the market
        uint256 collatReceived = IZapper(zapper).zapLeverage(collatToken, minCollatAmountReceived, routerCall);

        // Computes the amount
        (uint256 stakedAmount, IERC20 _collatToken) = _preDeposit(msg.sender, collatToDeposit + collatReceived, isStaked);

        // Transfer the collateral on the market
        _transferCollateralDeposit(_collatToken, collatToDeposit, false);

        // Performs same modification as in depositAndBorrow
        _depositAndBorrow(msg.sender, stakedAmount, tgUSDToFlashMint, true);

        _postDeposit(_collatToken, stakedAmount, isStaked);
    }
}

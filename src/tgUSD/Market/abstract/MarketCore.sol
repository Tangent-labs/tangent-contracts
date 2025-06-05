// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITgUSD} from "../../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IControlTower} from "../../../interfaces/internals/tgUSD/IControlTower.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {TokenAmount, ZapStruct, ZapStructDeposit} from "../../../interfaces/internals/ICommonStruct.sol";

import {PauseSettings} from "./PauseSettings.sol";
import {Collateral} from "./Collateral.sol";
import {ZappingUtil} from "../../Utilities/abstract/ZappingUtil.sol";

import {GlobalMarketInitParams, MarketInit, LiquidateCall, SelfLiquidateCall, IZappingProxy, IERC20} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";

import "forge-std/console.sol";

/// @notice
abstract contract MarketCore is PauseSettings, Collateral, ZappingUtil {
    using SafeERC20 for IERC20;
    IControlTower public controlTower;

    error DepositPaused();
    error BorrowPaused();
    error LeveragePaused();

    error AlreadyInitialized();
    error TotalDebtTooHigh();
    error UserDebtTooHigh();
    error UserDebtTooLow();
    error UserDebtZero();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotLiquidablePosition();
    error PositionWithoutBadDebt();

    constructor() {
        isInitialized = true;
    }

    modifier updateRewards(address _for) {
        rewardAccumulator.updateRewards(_for, collateralBalances[_for], totalCollateral);
        _;
    }

    function _initializationCommon(GlobalMarketInitParams memory _globalParams, MarketInit memory _marketInit) internal {
        require(!isInitialized, AlreadyInitialized());
        isInitialized = true;

        // Core
        tgUSD = _globalParams._tgUSD;
        controlTower = _globalParams._controlTower;
        irCalculator = _globalParams._irCalculator;
        rewardAccumulator = _globalParams._rewardAccumulator;
        zappingProxy = _globalParams._zappingProxy;

        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;

        // Can't be more than 100%
        require(_marketInit.liquidationThreshold < DENOMINATOR, LiquidationThresholdTooHigh());
        // Can't be less than the maxLTV
        require(_marketInit.liquidationThreshold > _marketInit.maxLTV, LiquidationThresholdTooLow());
        // Can't be more than 15%
        require(_marketInit.liquidationFee < 15_000, LiquidationFeeTooHigh());

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        liquidationFee = _marketInit.liquidationFee;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        // Gives ownership to the DAO
        _transferOwnership(_globalParams._owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @dev  Updates in the storage the Total debt, User debt and Collateral owned by an account
     *        Called during depositAndBorrow, withdrawAndReway, liquidate and selfLiquidate functions.
     *  @param account             Address of the account to update
     *  @param newCollatBalance    New collateral balance of account
     *  @param newUserDebtShares   New user debt shares of the account
     *  @param newTotalDebtShares  New total debt shares of the market
     */
    function _updateCollatAndDebts(address account, uint256 newCollatBalance, uint256 newTotalCollat, uint256 newUserDebtShares, uint256 newTotalDebtShares) internal {
        _updateCollateral(account, newCollatBalance, newTotalCollat);

        // Updates global and user debt
        _updateDebts(account, newUserDebtShares, newTotalDebtShares);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _depositSociabilization(uint256 lpDeposited, bool isStaked) internal virtual returns (uint256) {
        require(lpDeposited != 0, ZeroCollatAmount());
        return lpDeposited;
    }

    function _deposit(address _for, uint256 amountDeposited) internal {
        // Verify that newDebt is over the minimum loan
        irCalculator.checkpointIR(address(this));

        // Increase collateral balance of the position and update total debt
        _updateCollateral(_for, collateralBalances[_for] + amountDeposited, totalCollateral + amountDeposited);
    }

    function _postDeposit(IERC20 _collatToken, bool isStaked) internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _getBalanceAfterWithdrawAndCheckMaxBorrowable(uint256 amountToWithdraw, uint256 newUserDebt) internal view returns (uint256) {
        // Prevent to withdraw 0 collateral from the market
        require(amountToWithdraw != 0, ZeroCollatAmount());
        // Computes the decremented collateral balance of the user after the withdraw
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        // Verify that the newDebt of the loan is not over the maximum borrrowable regarding the LTV of the position
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, UserDebtTooHigh());
        return newCollatAmount;
    }

    function _withdraw(uint256 amountToWithdraw) internal {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        // Increase collateral deposited by the user
        _updateCollateral(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _userDebt(userDebtShares[msg.sender], newDebtIndex)),
            totalCollateral - amountToWithdraw
        );
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal virtual {
        collatToken.transfer(to, lpToWithdraw);
    }

    /* --------
                            BORROW 
                                                    ------ */

    function _borrow(address borrower, address receiver, uint256 tgUSDToBorrow, uint256 collatAmount, bool isLeverage) internal returns (uint256, uint256) {
        require(!isBorrowPaused, BorrowPaused());
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        uint256 _userDebtShares = userDebtShares[borrower];

        uint256 newUserDebt = tgUSDToBorrow + _userDebt(_userDebtShares, newDebtIndex);

        //  Cache the new value in tgUSD of the debt
        uint256 newUserDebtShares = (tgUSDToBorrow * RAY) / newDebtIndex;

        uint256 newTotalDebtShares = totalDebtShares + newUserDebtShares;

        //  Verify that the new total debt is not bigger the max debt
        require(_totalDebt(badDebt, newTotalDebtShares, newDebtIndex) <= maxMarketDebt, TotalDebtTooHigh());
        //  Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, UserDebtTooLow());

        // Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(collatAmount) >= newUserDebt, UserDebtTooHigh());

        // If it's a leverage transaction, tgUSD is already minted before
        if (!isLeverage) {
            // Mint tgUSD to the receiver
            tgUSD.mint(receiver, tgUSDToBorrow);
        }

        return (_userDebtShares + newUserDebtShares, newTotalDebtShares);
    }

    function _depositAndBorrow(address borrower, uint256 amountDeposited, uint256 tgUSDToBorrow, bool isLeverage) internal {
        // Collat amount after the deposit
        uint256 newCollatAmount = collateralBalances[borrower] + amountDeposited;

        (uint256 newUserDebtShare, uint256 newTotalDebtShares) = _borrow(borrower, borrower, tgUSDToBorrow, newCollatAmount, isLeverage);

        _updateCollatAndDebts(borrower, newCollatAmount, totalCollateral + amountDeposited, newUserDebtShare, newTotalDebtShares);
    }

    /* --------
                            REPAY
                                                    ------ */

    function _repay(address account, uint256 tgUSDToRepay) internal returns (uint256, uint256, uint256, uint256) {
        // Cannot repay 0 debt
        require(tgUSDToRepay != 0, ZeroDebtAmount());

        // Update interests rate, computes new debt index and total debt.
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        uint256 _userDebtShares = userDebtShares[account];

        uint256 oldUserDebt = _userDebt(_userDebtShares, newDebtIndex);

        // Cannot repay an empty position
        require(_userDebtShares != 0, UserDebtZero());

        uint256 newUserDebtShares;
        uint256 sharesToRemove;
        uint256 newUserDebt;

        // Repay all case
        // When IR != 0, debt of the user is increasing every block.
        // It is so complicated to provide the exact amount that a user has to repay to close his loan.
        // To cover this, any debt given in parameter that is equal or bigger than the debt will close the loan.
        if (tgUSDToRepay >= oldUserDebt) {
            // User shouldn't repay more than his debt so we rearrange the amount of tgUSD to repay.
            tgUSDToRepay = oldUserDebt;
            // As we are repaying all the debt, the new debt of the user is 0.
            newUserDebtShares = 0;

            sharesToRemove = _userDebtShares;
        }
        // Partial repay case
        else {
            // Retrieve the real debt of the user
            newUserDebt = oldUserDebt - tgUSDToRepay;

            sharesToRemove = (tgUSDToRepay * RAY) / newDebtIndex;

            newUserDebtShares = _userDebtShares - sharesToRemove;

            // We need to verify that the partial repay is not decreasing the debt lower than the minimum loan.
            require(newUserDebt >= minimumLoan, UserDebtTooLow());
        }

        return (tgUSDToRepay, newUserDebtShares, totalDebtShares - sharesToRemove, newUserDebt);
    }

    function _repayAndWithdraw(uint256 amountToWithdraw, uint256 tgUSDToRepay) internal returns (uint256) {
        // Call _repay function in order to checkpoint the total debt, computes new User debt and burn corresponding amount of tgUSD.
        (uint256 tgUSDToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, uint256 newUserDebt) = _repay(msg.sender, tgUSDToRepay);

        _updateCollatAndDebts(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebt),
            totalCollateral - amountToWithdraw,
            newUserDebtShares,
            newTotalDebtShares
        );

        return tgUSDToBurn;
    }

    /* --------
                            LIQUIDATION
                                                    ------ */

    function _preLiquidate(address account) internal returns (uint256, uint256, uint256, uint256) {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));
        uint256 userDebtShares_ = userDebtShares[account];
        return (newDebtIndex, collateralBalances[account], userDebtShares_, _userDebt(userDebtShares_, newDebtIndex));
    }

    function _selfLiquidate(SelfLiquidateCall memory selfLiquidateCall, ZapStruct calldata routerCall) internal returns (uint256) {
        // Need to some collateral
        require(selfLiquidateCall.collatAmountToLiquidate != 0, ZeroCollatAmount());
        // Computes the new collat balance
        uint256 newCollatBalance = selfLiquidateCall._collateralBalance - selfLiquidateCall.collatAmountToLiquidate;
        uint256 debtSharesToRemove;
        uint256 tgUSDToRepay = selfLiquidateCall.tgUSDToRepay;

        // Liquidate All
        if (tgUSDToRepay >= selfLiquidateCall.userDebt) {
            tgUSDToRepay = selfLiquidateCall.userDebt;
            debtSharesToRemove = selfLiquidateCall._userDebtShares;
        }
        // Liquidate partial
        else {
            debtSharesToRemove = (tgUSDToRepay * RAY) / selfLiquidateCall.newDebtIndex;

            uint256 newUserDebt = selfLiquidateCall.userDebt - tgUSDToRepay;
            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation
            require(newUserDebt >= minimumLoan, UserDebtTooLow());
            require(newUserDebt <= _maxBorrowable(newCollatBalance), UserDebtTooHigh());
        }

        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            msg.sender,
            newCollatBalance,
            selfLiquidateCall._totalCollateral - selfLiquidateCall.collatAmountToLiquidate,
            selfLiquidateCall._userDebtShares - debtSharesToRemove,
            selfLiquidateCall._totalDebtShares - debtSharesToRemove
        );

        _postLiquidate(selfLiquidateCall.collatAmountToLiquidate, tgUSDToRepay, selfLiquidateCall.minTgUSDOut, routerCall);

        return tgUSDToRepay;
    }

    function _liquidate(LiquidateCall memory liquidateCall, ZapStruct calldata routerCall) internal returns (uint256, uint256, uint256) {
        uint256 collatAmountToLiquidate = liquidateCall.collatToLiquidate;
        require(liquidateCall.collatToLiquidate != 0, ZeroCollatAmount());

        uint256 newCollatBalance;
        uint256 debtSharesToRemove;
        uint256 tgUSDToRepay;

        // Liquidate all
        if (collatAmountToLiquidate >= liquidateCall._collateralBalance) {
            collatAmountToLiquidate = liquidateCall._collateralBalance;
            tgUSDToRepay = liquidateCall.userDebt;
            debtSharesToRemove = liquidateCall._userDebtShares;
        }
        // Liquidate partial
        else {
            tgUSDToRepay = (collatAmountToLiquidate * liquidateCall.userDebt) / liquidateCall._collateralBalance;
            debtSharesToRemove = (tgUSDToRepay * RAY) / liquidateCall.newDebtIndex;
            // Computes the new balance of collateral after the partial liquidation
            newCollatBalance = liquidateCall._collateralBalance - collatAmountToLiquidate;

            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation
            require(liquidateCall.userDebt - tgUSDToRepay >= minimumLoan, UserDebtTooLow());
        }
        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            liquidateCall.account,
            newCollatBalance,
            liquidateCall._totalCollateral - collatAmountToLiquidate,
            liquidateCall._userDebtShares - debtSharesToRemove,
            liquidateCall._totalDebtShares - debtSharesToRemove
        );

        uint256 fee = (tgUSDToRepay * liquidationFee) / DENOMINATOR;

        _postLiquidate(collatAmountToLiquidate, tgUSDToRepay + fee, liquidateCall.minTgUSDOut, routerCall);

        if (fee != 0) {
            tgUSD.mint(controlTower.feeTreasury(), fee);
        }

        return (collatAmountToLiquidate, tgUSDToRepay, fee);
    }

    function _postLiquidate(uint256 collatAmountToLiquidate, uint256 tgUSDToBurn, uint256 minTgUSDOut, ZapStruct calldata routerCall) internal {
        IZappingProxy _zappingProxy = zappingProxy;
        // Withdraw the collateral from the underlying protocol if needed and
        // Transfer it to the caller when there is no liquidator passed in parameter
        // If a liquidator is passed, we send the collateral to the Zapping Proxy that will handle the sell of the collateral.
        _transferCollateralWithdraw(routerCall.router != address(0) ? address(_zappingProxy) : msg.sender, collatAmountToLiquidate);
        // When liquidator is not zero, it allows to the LiquidatorProxy to receive the collateral.
        // Then, if needed, liquidator will allow the custom Liquidator to sell the collateral for tgUSD in the same transaction.
        if (routerCall.router != address(0)) {
            _zappingProxy.zapProxy(collatToken, tgUSD, minTgUSDOut, msg.sender, routerCall);
        }

        // Burns tgUSD from the sender.
        // The debt has to be on the caller of the transaction.
        // In case a liquidator is passed in parameter, it needs to send it back to the sender of the tx.
        tgUSD.burnFrom(msg.sender, tgUSDToBurn);
    }

    function _seizeCollateral(
        address account,
        uint256 _collateralBalance,
        uint256 _totalCollateral,
        uint256 _userDebtShares,
        uint256 _totalDebtShares,
        uint256 _accountDebt
    ) internal {
        // Updates total and user values for collaterals & debts
        // Collat Balance and user debt are updated to 0 because the whole position is liquidated
        _updateCollatAndDebts(account, 0, _totalCollateral - _collateralBalance, 0, _totalDebtShares - _userDebtShares);

        // Bad debt is written in the market
        badDebt += _accountDebt;

        // The collateral is sent to the DAO to decide what to do with it
        _transferCollateralWithdraw(controlTower.feeTreasury(), _collateralBalance);
    }

    /* --------
                        LEVERAGE
                                                    ------ */

    function _preLeverage() internal view {
        require(!isDepositPaused, DepositPaused());
        require(!isBorrowPaused, BorrowPaused());
        require(!isLeveragePaused, LeveragePaused());
    }

    function _leverage(
        IERC20 _collatToken,
        uint256 collatToDeposit,
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata dumpTgUSDCall
    ) internal returns (uint256, uint256) {
        ITgUSD _tgUSD = tgUSD;

        IZappingProxy _zappingProxy = zappingProxy;

        // Mint the tgUSD on the Zapper, ready to be exchanged through the router
        _tgUSD.mint(address(_zappingProxy), tgUSDToFlashMint);
        // Exchange the tgUSD that has just been minted on the Zapper for the collateral of the market
        uint256 collatBought = _zappingProxy.zapProxy(_tgUSD, collatToken, minCollatAmountOut, address(this), dumpTgUSDCall);

        uint256 stakedAmount = _depositSociabilization(collatToDeposit + collatBought, isStaked);

        // Performs same modification as in depositAndBorrow
        _depositAndBorrow(msg.sender, stakedAmount, tgUSDToFlashMint, true);

        _postDeposit(_collatToken, isStaked);

        return (collatBought, stakedAmount);
    }

    function _claimUnderlyingRewards(IERC20[] memory _rewardTokens) internal returns (TokenAmount[] memory) {
        uint256 rewardLen = _rewardTokens.length;
        TokenAmount[] memory rewardAmounts = new TokenAmount[](rewardLen);
        address _rewardAccumulator = address(rewardAccumulator);

        uint256 counter;

        for (uint256 i; i < rewardLen; ) {
            IERC20 rewardToken = _rewardTokens[i];
            uint256 balance = rewardToken.balanceOf(address(this));
            if (balance != 0) {
                rewardAmounts[counter++] = TokenAmount({token: rewardToken, amount: balance});
                rewardToken.safeTransfer(address(_rewardAccumulator), balance);
            }

            unchecked {
                ++i;
            }
        }

        /// @dev Reduce length of tokenAmounts struct to not return useless 0
        if (rewardAmounts.length != 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(rewardAmounts, sub(mload(rewardAmounts), sub(rewardLen, counter)))
            }
        }

        return rewardAmounts;
    }
}

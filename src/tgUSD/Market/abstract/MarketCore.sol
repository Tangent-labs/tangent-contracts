// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IControlTower} from "../../../interfaces/internals/tgUSD/IControlTower.sol";
import {PauseSettings} from "./PauseSettings.sol";
import {Rewards} from "./Rewards.sol";
import {GlobalMarketInitParams, MarketInit, LiquidateCall} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketCore is PauseSettings, Rewards {
    IControlTower public controlTower;

    error AlreadyInitialized();
    error TotalDebtTooHigh();
    error PositionDebtTooHigh();
    error PositionDebtTooLow();
    error PositionDebtZero();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotLiquidablePosition();
    error PositionWithoutBadDebt();
    error NotZapper(address zapper);

    event Liquidate(address indexed account, uint256 repaidAmount, uint256 collateralLiquidated, address liquidator);

    constructor() {
        isInitialized = true;
    }

    function _initializationCommon(GlobalMarketInitParams memory _globalParams, MarketInit memory _marketInit) internal {
        require(!isInitialized, AlreadyInitialized());
        isInitialized = true;
        // Rewards
        rewardCutPercentage = 50_000;
        harvesterFeePercentage = 1_000;

        // Rewards
        for (uint256 i; i < _marketInit._rewardTokens.length; ) {
            IERC20Metadata token = _marketInit._rewardTokens[i];
            rewardTokens.push(token);
            rewardData[token].lastUpdateTime = uint128(block.timestamp);
            rewardData[token].periodFinish = uint128(block.timestamp);

            unchecked {
                ++i;
            }
        }

        // Core
        tgUSD = _globalParams._tgUSD;
        controlTower = _globalParams._controlTower;
        irCalculator = _globalParams._irCalculator;
        rewardAccumulator = _globalParams._rewardAccumulator;
        liquidatorProxy = _globalParams._liquidatorProxy;

        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        lastIR = 10 * RAY; // 10%
        blockLastIRTimestamp = block.timestamp;
        debtIndex = RAY;

        // Gives ownership to the DAO
        _transferOwnership(_globalParams._owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @dev  Updates in the storage the Total debt, User debt and Collateral owned by an account
     *        Called during depositAndBorrow, withdrawAndReway, liquidate and selfLiquidate functions.
     *  @param account           Address of the account to update
     *  @param newCollatBalance  New collateral balance of account
     *  @param newUserDebt       New debt of the account
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     */
    function _updateCollatAndDebts(address account, uint256 newCollatBalance, uint256 newTotalCollat, uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        _updateCollateral(account, newCollatBalance, newTotalCollat);

        // Updates global and user debt
        _updateDebts(account, newUserDebt, newDebtIndex, newTotalDebt);
    }

    /**
     *  @dev  Updates in the storage the Total debt and Collateral owned by an account
     *        Called during simple deposit and withdraw.
     *  @param account           Address of the account to update
     *  @param newCollatBalance  New collateral balance of account
     *  @param newDebtIndex      New index of the debt
     *  @param newTotalDebt      New total debt of the market
     */
    function _updateCollatAndGlobalDebt(address account, uint256 newCollatBalance, uint256 newTotalCollat, uint256 newDebtIndex, uint256 newTotalDebt) internal {
        _updateCollateral(account, newCollatBalance, newTotalCollat);
        // Updates global debt
        _updateGlobalDebt(newDebtIndex, newTotalDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal virtual returns (uint256, IERC20) {}

    function _deposit(address _for, uint256 amountDeposited) internal {
        // Verify that newDebt is over the minimum loan
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        // Increase collateral balance of the position and update total debt
        _updateCollatAndGlobalDebt(_for, collateralBalances[_for] + amountDeposited, totalCollateral + amountDeposited, newDebtIndex, newTotalDebt);
    }

    function _transferCollateralDeposit(IERC20 _collatToken, uint256 lpDeposited, bool isZapping) internal {
        // When caller is not one of our Zapper, sender needs to send collateral token to the market.
        // Zapper send the collateral directly on the market before calling "deposit"
        if (!isZapping) {
            // Transfer the collateral from the sender to the market
            _collatToken.transferFrom(msg.sender, address(this), lpDeposited);
        }
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
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, PositionDebtTooHigh());
        return newCollatAmount;
    }

    function _withdraw(uint256 amountToWithdraw) internal {
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        // Increase collateral deposited by the user
        _updateCollatAndGlobalDebt(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _positionDebt(msg.sender, newDebtIndex)),
            totalCollateral - amountToWithdraw,
            newDebtIndex,
            newTotalDebt
        );
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal virtual {}

    /* --------
                            BORROW 
                                                    ------ */

    function _borrow(address borrower, address receiver, uint256 tgUSDToBorrow, uint256 collatAmount, bool isLeverage) internal returns (uint256, uint256, uint256) {
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        newTotalDebt += tgUSDToBorrow;

        //  Cache the new value in tgUSD of the debt
        uint256 newUserDebt = _positionDebt(borrower, newDebtIndex) + tgUSDToBorrow;

        //  Verify that the new total debt is not bigger the max debt
        require(newTotalDebt + badDebt <= maxMarketDebt, TotalDebtTooHigh());
        //  Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, PositionDebtTooLow());

        // Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(collatAmount) >= newUserDebt, PositionDebtTooHigh());

        // If it's a leverage transaction, tgUSD is already minted before
        if (!isLeverage) {
            // Mint tgUSD to the receiver
            tgUSD.mint(receiver, tgUSDToBorrow);
        }

        return (newUserDebt, newDebtIndex, newTotalDebt);
    }

    function _depositAndBorrow(address borrower, uint256 amountDeposited, uint256 tgUSDToBorrow, bool isLeverage) internal {
        // Collat amount after the deposit
        uint256 newCollatAmount = collateralBalances[borrower] + amountDeposited;

        (uint256 newUserDebt, uint256 newDebtIndex, uint256 newTotalDebt) = _borrow(borrower, borrower, tgUSDToBorrow, newCollatAmount, isLeverage);

        _updateCollatAndDebts(borrower, newCollatAmount, totalCollateral + amountDeposited, newUserDebt, newDebtIndex, newTotalDebt);
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

        _updateCollatAndDebts(
            caller,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebt),
            totalCollateral - amountToWithdraw,
            newUserDebt,
            newDebtIndex,
            newTotalDebt
        );
    }

    /* --------
                        LIQUIDATION
                                                    ------ */

    function _preLiquidate(address account) internal returns (uint256, uint256, uint256, uint256) {
        // Checkpoint IR
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkpointIR();

        return (newDebtIndex, newTotalDebt, _positionDebt(account, newDebtIndex), collateralBalances[account]);
    }

    function _liquidate(LiquidateCall memory liquidateCall, address liquidator, uint256 minTgUSDOut, bytes calldata liquidationCall) internal {
        require(liquidateCall.tgUSDToRepay != 0, ZeroDebtAmount());

        uint256 collatAmountToLiquidate;
        uint256 newCollatBalance;
        uint256 remainingDebt;
        uint256 tgUSDToRepay;

        // Liquidate all
        if (liquidateCall.tgUSDToRepay >= liquidateCall.userDebt) {
            tgUSDToRepay = liquidateCall.userDebt;
            collatAmountToLiquidate = liquidateCall.collatBalance;
        }
        // Liquidate partial
        else {
            tgUSDToRepay = liquidateCall.tgUSDToRepay;
            // Computes the amount of collateral to liquidate by proportionnality
            collatAmountToLiquidate = (liquidateCall.collatBalance * tgUSDToRepay) / liquidateCall.userDebt;
            // Computes the new balance of collateral after the partial liquidation
            newCollatBalance = liquidateCall.collatBalance - collatAmountToLiquidate;
            // Computes the debt remaining for the position
            remainingDebt = liquidateCall.userDebt - tgUSDToRepay;
            // Ensure that the remaining debt is bigger than a minimum in order to leave a profitable liquidation
            require(remainingDebt >= minimumLoan, PositionDebtTooLow());
        }

        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            liquidateCall.account,
            newCollatBalance,
            totalCollateral - collatAmountToLiquidate,
            remainingDebt,
            liquidateCall.newDebtIndex,
            liquidateCall.newTotalDebt - tgUSDToRepay
        );

        // Withdraw the collateral from the underlying protocol if needed and
        // Transfer it to the caller when there is no liquidator passed in parameter
        // If a liquidator is passed, we send the collateral to the liquidator
        _transferCollateralWithdraw(liquidator != address(0) ? liquidator : msg.sender, collatAmountToLiquidate);

        // When liquidator is not zero, it allows to the LiquidatorProxy to receive the collateral.
        // Then, if needed, liquidator will allow the custom Liquidator to sell the collateral for tgUSD in the same transaction.
        if (liquidator != address(0)) {
            liquidatorProxy.callLiquidate(liquidator, msg.sender, minTgUSDOut, liquidationCall);
        }
        // Burns tgUSD from the sender.
        // The debt has to be on the caller of the transaction.
        // In case a liquidator is passed in parameter, it needs to send it back to the sender of the tx.
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);

        emit Liquidate(liquidateCall.account, tgUSDToRepay, collatAmountToLiquidate, liquidator);
    }

    function _liquidateBadDebt(address account, uint256 userDebt, uint256 collatBalance, uint256 newTotalDebt, uint256 newDebtIndex) internal {
        // Updates total and user values for collaterals & debts
        // Collat Balance and user debt are updated to 0 because the whole position is liquidated
        _updateCollatAndDebts(account, 0, totalCollateral - collatBalance, 0, newDebtIndex, newTotalDebt - userDebt);
        // The collateral is sent to the DAO to decide what to do with it
        //TODO Check who is the receiver of the collateral
        _transferCollateralWithdraw(controlTower.feeTreasury(), collatBalance);

        // Bad debt is written in the market
        badDebt += userDebt;
    }

    /* --------
                        LEVERAGE
                                                    ------ */

    function _checkZapper(address callerZapper) internal view returns (bool, address) {
        bool isZapping;
        if (address(callerZapper) != address(0)) {
            isZapping = controlTower.isZapper(msg.sender);
        } else {
            callerZapper = msg.sender;
        }
        callerZapper = isZapping ? callerZapper : msg.sender;

        return (isZapping, callerZapper);
    }
}

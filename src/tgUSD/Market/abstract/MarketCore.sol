// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IControlTower} from "../../../interfaces/internals/tgUSD/IControlTower.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";

import {PauseSettings} from "./PauseSettings.sol";
import {Collateral} from "./Collateral.sol";
import {GlobalMarketInitParams, MarketInit, LiquidateCall, SelfLiquidateCall, ILiquidatorProxy} from "../../../interfaces/internals/tgUSD/IMarketCore.sol";

import "forge-std/console.sol";

/// @notice
abstract contract MarketCore is PauseSettings, Collateral {
    using SafeERC20 for IERC20;
    IControlTower public controlTower;

    /// @notice Liquidation proxy
    ILiquidatorProxy public liquidatorProxy;

    error AlreadyInitialized();
    error TotalDebtTooHigh();
    error UserDebtTooHigh();
    error UserDebtTooLow();
    error UserDebtZero();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotLiquidablePosition();
    error PositionWithoutBadDebt();
    error NotZapper(address zapper);

    event Liquidate(address indexed account, uint256 repaidAmount, uint256 collateralLiquidated, address liquidator);
    event SelfLiquidate(address indexed account, uint256 repaidAmount, uint256 collateralLiquidated, address liquidator);

    constructor() {
        isInitialized = true;
    }

    function _initializationCommon(GlobalMarketInitParams memory _globalParams, MarketInit memory _marketInit) internal {
        require(!isInitialized, AlreadyInitialized());
        isInitialized = true;

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

    /**
     *  @dev  Updates in the storage the Total debt and Collateral owned by an account
     *        Called during simple deposit and withdraw.
     *  @param account           Address of the account to update
     *  @param newCollatBalance  New collateral balance of account
     */
    function _updateCollatAndGlobalDebt(address account, uint256 newCollatBalance, uint256 newTotalCollat) internal {
        _updateCollateral(account, newCollatBalance, newTotalCollat);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal virtual returns (uint256, IERC20) {}

    function _deposit(address _for, uint256 amountDeposited) internal {
        // Verify that newDebt is over the minimum loan
        irCalculator.checkpointIR(address(this));

        // Increase collateral balance of the position and update total debt
        _updateCollatAndGlobalDebt(_for, collateralBalances[_for] + amountDeposited, totalCollateral + amountDeposited);
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
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, UserDebtTooHigh());
        return newCollatAmount;
    }

    function _withdraw(uint256 amountToWithdraw) internal {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        // Increase collateral deposited by the user
        _updateCollatAndGlobalDebt(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _userDebt(userDebtShares[msg.sender], newDebtIndex)),
            totalCollateral - amountToWithdraw
        );
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal virtual {}

    /* --------
                            BORROW 
                                                    ------ */

    function _borrow(address borrower, address receiver, uint256 tgUSDToBorrow, uint256 collatAmount, bool isLeverage) internal returns (uint256, uint256) {
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

    function _repay(address account, uint256 tgUSDToRepay, address burnAddress) internal returns (uint256, uint256) {
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
            uint256 newUserDebt = oldUserDebt - tgUSDToRepay;

            sharesToRemove = (tgUSDToRepay * RAY) / newDebtIndex;

            newUserDebtShares = _userDebtShares - sharesToRemove;

            // We need to verify that the partial repay is not decreasing the debt lower than the minimum loan.
            require(newUserDebt >= minimumLoan, UserDebtTooLow());
        }

        // Burns tgUSD from the burnAddress as a repayment of the debt
        tgUSD.burnFrom(burnAddress, tgUSDToRepay);
        return (newUserDebtShares, totalDebtShares - sharesToRemove);
    }

    function _withdrawAndRepay(uint256 amountToWithdraw, uint256 tgUSDToRepay, address caller) internal {
        // Call _repay function in order to checkpoint the total debt, computes new User debt and burn corresponding amount of tgUSD.
        (uint256 newUserDebtShares, uint256 newTotalDebtShares) = _repay(caller, tgUSDToRepay, caller);

        //TODO Problem with the _getBalanceAfterWithdrawAndCheckMaxBorrowable
        _updateCollatAndDebts(
            caller,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebtShares),
            totalCollateral - amountToWithdraw,
            newUserDebtShares,
            newTotalDebtShares
        );
    }

    /* --------
                            LIQUIDATION
                                                    ------ */
    //TODO Add some check on min Loan and LTV
    function _selfLiquidate(SelfLiquidateCall memory selfLiquidateCall, bytes calldata liquidationCall) internal {
        require(selfLiquidateCall.collatAmountToLiquidate != 0, ZeroCollatAmount());
        uint256 newCollatBalance = selfLiquidateCall._collateralBalance - selfLiquidateCall.collatAmountToLiquidate;
        uint256 debtSharesToRemove;
        uint256 tgUSDToRepay = selfLiquidateCall.tgUSDToRepay;

        // Repay all debt
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

        _postLiquidate(selfLiquidateCall.liquidator, selfLiquidateCall.collatAmountToLiquidate, tgUSDToRepay, selfLiquidateCall.minTgUSDOut, liquidationCall);

        emit SelfLiquidate(msg.sender, tgUSDToRepay, selfLiquidateCall.collatAmountToLiquidate, selfLiquidateCall.liquidator);
    }

    function _liquidate(LiquidateCall memory liquidateCall, bytes calldata liquidationCall) internal {
        require(liquidateCall.tgUSDToRepay != 0, ZeroDebtAmount());

        uint256 collatAmountToLiquidate;
        uint256 newCollatBalance;
        uint256 debtSharesToRemove;
        uint256 tgUSDToRepay = liquidateCall.tgUSDToRepay;

        // Liquidate all
        if (tgUSDToRepay >= liquidateCall.userDebt) {
            tgUSDToRepay = liquidateCall.userDebt;
            collatAmountToLiquidate = liquidateCall._collateralBalance;
            debtSharesToRemove = liquidateCall._userDebtShares;
        }
        // Liquidate partial
        else {
            debtSharesToRemove = (tgUSDToRepay * RAY) / liquidateCall.newDebtIndex;

            // Computes the amount of collateral to liquidate by proportionnality
            collatAmountToLiquidate = (liquidateCall._collateralBalance * tgUSDToRepay) / liquidateCall.userDebt;
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
        _postLiquidate(liquidateCall.liquidator, collatAmountToLiquidate, tgUSDToRepay, liquidateCall.minTgUSDOut, liquidationCall);

        emit Liquidate(liquidateCall.account, tgUSDToRepay, collatAmountToLiquidate, liquidateCall.liquidator);
    }

    function _postLiquidate(address liquidator, uint256 collatAmountToLiquidate, uint256 tgUSDToRepay, uint256 minTgUSDOut, bytes calldata liquidationCall) internal {
        ILiquidatorProxy _liquidatorProxy = liquidatorProxy;
        // Withdraw the collateral from the underlying protocol if needed and
        // Transfer it to the caller when there is no liquidator passed in parameter
        // If a liquidator is passed, we send the collateral to the liquidator
        _transferCollateralWithdraw(liquidator != address(0) ? address(_liquidatorProxy) : msg.sender, collatAmountToLiquidate);

        // When liquidator is not zero, it allows to the LiquidatorProxy to receive the collateral.
        // Then, if needed, liquidator will allow the custom Liquidator to sell the collateral for tgUSD in the same transaction.
        if (liquidator != address(0)) {
            _liquidatorProxy.callLiquidate(liquidator, msg.sender, collatToken, minTgUSDOut, liquidationCall);
        }

        // Burns tgUSD from the sender.
        // The debt has to be on the caller of the transaction.
        // In case a liquidator is passed in parameter, it needs to send it back to the sender of the tx.
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);
    }

    function _liquidateBadDebt(
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
        // The collateral is sent to the DAO to decide what to do with it
        //TODO Check who is the receiver of the collateral
        _transferCollateralWithdraw(controlTower.feeTreasury(), _collateralBalance);

        // Bad debt is written in the market
        badDebt += _accountDebt;
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

    function _claimUnderlyingRewards(IERC20[] memory _rewardTokens) internal returns (TokenAmount[] memory) {
        uint256 rewardLen = _rewardTokens.length;
        TokenAmount[] memory rewardAmounts = new TokenAmount[](rewardLen);
        address _rewardAccumulator = address(rewardAccumulator);

        uint256 counter;
        //TODO Test here with some 0
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

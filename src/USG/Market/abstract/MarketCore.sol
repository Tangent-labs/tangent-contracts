// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../../interfaces/internals/USG/IControlTower.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {TokenAmount, ZapStruct, ZapStructDeposit} from "../../../interfaces/internals/ICommonStruct.sol";

import {PauseSettings} from "./PauseSettings.sol";
import {Collateral} from "./Collateral.sol";
import {ZappingUtil} from "../../Utilities/abstract/ZappingUtil.sol";

import {
    GlobalMarketInitParams,
    MarketInit,
    LiquidationPre,
    LiquidateIn,
    LiquidateTransitionStruct,
    SelfLiquidateIn,
    SelfLiquidateTransitionStruct,
    PostLiquidate,
    LeverageIn,
    IZappingProxy,
    IERC20
} from "../../../interfaces/internals/USG/IMarketCore.sol";

/// @title MarketCore
/// @author Tangent Finance
/// @notice Abstract base contract implementing core functionality for USG markets.
/// @dev Inherits PauseSettings, Collateral and ZappingUtil to provide collateral management
/// Includes core logic for deposits, withdrawals, borrowing, repayment, liquidation, and leverage.
abstract contract MarketCore is PauseSettings, Collateral, ZappingUtil {
    using SafeERC20 for IERC20;

    /// @notice Errors to signal specific failure conditions in market operations.

    error AlreadyInitialized();
    error NotLiquidablePosition();
    error PositionWithoutBadDebt();
    error NotAMigratoor();
    error DebtToRepayTooBig();
    error MaxUSGToBurn();
    error NotEnoughCollateralToLiquidate(uint256 collatBalance);
    error CollatValueToLiquidateTooLow(uint256 collatValue);
    error MinCollatToLiquidate(uint256 collatAmount);
    error NoZapLiquidateWithReceipt();

    /// @notice Constructor marks the contract as initialized.
    constructor() {
        isInitialized = 1;
    }

    /// @notice Modifier to update rewards for a given account before running function logic.
    /// @param _for Address for which to update rewards.
    modifier updateRewards(address _for) {
        rewardAccumulator.updateRewards(_for, collateralBalances[_for], totalCollateral);
        _;
    }

    /// @notice Internal common initialization called during market setup.
    /// @param _globalParams Global parameters such as USG, controlTower, interest rate calculator, etc.
    /// @param _marketInit Market specific initialization parameters including collateral token, oracles, LTVs.
    function _initializationCommon(GlobalMarketInitParams memory _globalParams, MarketInit memory _marketInit) internal {
        require(isInitialized == 0, AlreadyInitialized());
        isInitialized = 1;

        // Core references initialization
        usg = _globalParams._USG;
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
        // Can't be more than 80%
        require(_marketInit.liquidationFee <= 80_000, LiquidationFeeTooHigh());

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        liquidationFee = _marketInit.liquidationFee;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        collatDecimals = collatToken.decimals();

        // Transfer ownership to the DAO
        _transferOwnership(_globalParams._owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL STORAGE UPDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Updates storage values related to collateral and debt for an account.
     * @dev    Called on deposit/borrow, withdraw/repay, liquidation and self liquidation.
     * @param account            Address of the user whose state is updated.
     * @param newCollatBalance   Updated collateral balance of the user.
     * @param newTotalCollat     Updated total collateral of the market.
     * @param newUserDebtShares  Updated user debt shares.
     * @param newTotalDebtShares Updated total debt shares of the market.
     */
    function _updateCollatAndDebts(address account, uint256 newCollatBalance, uint256 newTotalCollat, uint256 newUserDebtShares, uint256 newTotalDebtShares) internal {
        // Updates total and use collateral
        _updateCollateral(account, newCollatBalance, newTotalCollat);

        // Updates total and user debt shares
        _updateDebts(account, newUserDebtShares, newTotalDebtShares);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Internal function called during 'deposit' external function.
     * @param _for            Address of the user/position receiving collateral.
     * @param amountDeposited Amount of collateral deposited.
     */
    function _deposit(address _for, uint256 amountDeposited, IERC20 _collatToken) internal {
        require(_for != address(0));
        // Cannot deposit on a market with paused deposits
        _verifyIsDepositNotPaused();
        // Cannot deposit 0
        _verifyCollatInputNotZero(amountDeposited);
        // Checkpoint the IR and indexes
        _checkpointIR();
        // Increase collateral balance of the position and update total debt
        _updateCollateral(_for, collateralBalances[_for] + amountDeposited, totalCollateral + amountDeposited);

        _postDeposit(_collatToken);
    }

    /**
     * @dev Hook after deposit to allow extended logic such as staking the collateral in an underlying protocol.
     *      When not override, does nothing. Otherwise, refers to the overriding implementation.
     * @param _collatToken Collateral token being deposited.
     */
    function _postDeposit(IERC20 _collatToken) internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev   Internal function called during 'withdraw' external function.
     * @param amountToWithdraw Amount of collateral to withdraw.
     * @param isReceiptOut     When true, receipt token is sent back, when false it's the underlying
     */
    function _withdraw(uint256 amountToWithdraw, bool isReceiptOut) internal {
        // Checkpoint the IR and indexes
        uint256 newDebtIndex = _checkpointIR();

        // Increase collateral deposited by the user
        _updateCollateral(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _convertToAmount(userDebtShares[msg.sender], newDebtIndex, Math.Rounding.Ceil)),
            totalCollateral - amountToWithdraw
        );

        _transferCollateralWithdraw(msg.sender, amountToWithdraw, isReceiptOut);
    }

    /**
     * @dev Computes new collateral balance after withdrawal and checks borrowing limit of maxLTV.
     * @param amountToWithdraw Amount of collateral to withdraw.
     * @param newUserDebt      New user debt of the user.
     * @return Collateral of the user post withdraw
     */
    function _getBalanceAfterWithdrawAndCheckMaxBorrowable(uint256 amountToWithdraw, uint256 newUserDebt) internal returns (uint256) {
        // Prevent to withdraw 0 collateral from the market
        _verifyCollatInputNotZero(amountToWithdraw);
        // Computes the decremented collateral balance of the user after the withdraw
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        // Verify that the newDebt of the loan is not over the maximum borrrowable regarding the LTV of the position
        _verifyMaxLTV(newCollatAmount, newUserDebt, false);

        return newCollatAmount;
    }

    /**
     * @dev Hook transfering collateral to the user.
     *      When not override, transfer the collateral from the market to the user. Otherwise, refers to the overriding implementation.
     * @param collatToDeposit Amount of collateral to withdraw from the market.
     * @param isReceiptIn     Choose to deposit with the receipt token or the LP.
     */
    function _transferCollateralDeposit(uint256 collatToDeposit, bool isReceiptIn) internal virtual {
        collatToken.transferFrom(msg.sender, address(this), collatToDeposit);
    }

    /**
     * @dev Hook transfering collateral to the user.
     *      When not override, transfer the collateral from the market to the user. Otherwise, refers to the overriding implementation.
     * @param to               Receiver of the collatToken withdrawn
     * @param collatToWithdraw Amount of collateral to withdraw from the market.
     * @param isReceiptOut     When true, receipt token is sent back, when false it's the underlying
     */
    function _transferCollateralWithdraw(address to, uint256 collatToWithdraw, bool isReceiptOut) internal virtual {
        collatToken.transfer(to, collatToWithdraw);
    }

    /* --------
                            BORROW 
                                                    ------ */

    /**
     * @dev  Internal function called during 'borrow', 'depositAndBorrow' and 'leverage' external functions.
     * @param  receiver      Address receiving the borrowed USG.
     * @param  usgToBorrow Amount of USG to borrow.
     * @param  collatAmount  Amount of collateral owned by borrower.
     * @param  isLeverage    Whether this borrow is part of a leverage transaction.
     * @return userDebtShares updated after borrow
     * @return totalDebtShares updated of the market after borrow
     */
    function _borrow(address receiver, uint256 usgToBorrow, uint256 collatAmount, bool isLeverage) internal returns (uint256, uint256) {
        _verifyIsBorrowNotPaused();
        _verifyDebtInputNotZero(usgToBorrow);
        uint256 newDebtIndex = _checkpointIR();

        uint256 _userDebtShares = userDebtShares[msg.sender];

        uint256 newUserDebt = usgToBorrow + _convertToAmount(_userDebtShares, newDebtIndex, Math.Rounding.Ceil);

        //  Cache the new value in USG of the debt
        uint256 newUserDebtShares = _convertToShares(usgToBorrow, newDebtIndex, Math.Rounding.Ceil);
        uint256 newTotalDebtShares = totalDebtShares + newUserDebtShares;

        _verifyDebtCap(newTotalDebtShares, newDebtIndex);

        //  Verify that newDebt is over the minimum loan
        _verifyMinimumDebt(newUserDebt);

        // Verify that the newDebt of the loan is not over the maximum borrrowable
        _verifyMaxLTV(collatAmount, newUserDebt, false);

        // If it's a leverage transaction, USG is already minted before
        if (!isLeverage) {
            // Mint USG to the receiver
            _mintUSG(usg, receiver, usgToBorrow);
        }

        return (_userDebtShares + newUserDebtShares, newTotalDebtShares);
    }

    /**
     * @dev  Internal function called during 'depositAndBorrow' and 'leverage' external functions.
     * @param amountDeposited Amount of collateral to deposit.
     * @param usgToBorrow   Amount of USG to borrow.
     * @param isLeverage      Whether this borrow is part of a leverage transaction.
     */
    function _depositAndBorrow(uint256 amountDeposited, uint256 usgToBorrow, IERC20 _collatToken, bool isLeverage) internal returns (uint256) {
        _verifyIsDepositNotPaused();
        // Cannot deposit 0
        _verifyCollatInputNotZero(amountDeposited);
        // Collat amount after the deposit
        uint256 newCollatAmount = collateralBalances[msg.sender] + amountDeposited;

        (uint256 newUserDebtShare, uint256 newTotalDebtShares) = _borrow(msg.sender, usgToBorrow, newCollatAmount, isLeverage);

        _updateCollatAndDebts(msg.sender, newCollatAmount, totalCollateral + amountDeposited, newUserDebtShare, newTotalDebtShares);

        _postDeposit(_collatToken);

        return newUserDebtShare;
    }

    /* --------
                            REPAY
                                                    ------ */

    /**
     * @dev  Internal function called during 'repay' and 'repayAndWithdraw' external functions.
     * @param account        Address that will have its debt repaid
     * @param USGToRepay   Amount of USG to repay. When this amount is bigger than the actual debt of the user, is replaced by the real debt afterwards.
     * @return Amount of USG to burn from the sender
     * @return New user debt shares
     * @return New total debt shares
     * @return New user debt
     */
    function _repay(address account, uint256 USGToRepay) internal returns (uint256, uint256, uint256, uint256) {
        // Cannot repay 0 debt
        _verifyDebtInputNotZero(USGToRepay);

        // Update interests rate, computes new debt index and total debt.
        uint256 newDebtIndex = _checkpointIR();

        uint256 _userDebtShares = userDebtShares[account];

        uint256 oldUserDebt = _convertToAmount(_userDebtShares, newDebtIndex, Math.Rounding.Ceil);

        // Cannot repay an empty position
        require(_userDebtShares != 0, UserDebtZero());

        uint256 newUserDebtShares;
        uint256 sharesToRemove;
        uint256 newUserDebt;

        // Repay all case
        // When IR != 0, debt of the user is increasing every block.
        // It is so complicated to provide the exact amount that a user has to repay to close his loan.
        // To cover this, any debt given in parameter that is equal or bigger than the debt will close the loan.
        if (USGToRepay >= oldUserDebt) {
            // User shouldn't repay more than his debt so we rearrange the amount of USG to repay.
            USGToRepay = oldUserDebt;
            // As we are repaying all the debt, the new debt of the user is 0.
            newUserDebtShares = 0;

            sharesToRemove = _userDebtShares;
        }
        // Partial repay case
        else {
            // Retrieve the real debt of the user
            newUserDebt = oldUserDebt - USGToRepay;

            sharesToRemove = _convertToShares(USGToRepay, newDebtIndex, Math.Rounding.Floor);

            newUserDebtShares = _userDebtShares - sharesToRemove;

            // We need to verify that the partial repay is not decreasing the debt lower than the minimum loan.
            _verifyMinimumDebt(newUserDebt);
        }

        require(sharesToRemove != 0, ZeroDebtAmount());

        _burnUSG(msg.sender, USGToRepay);

        return (USGToRepay, newUserDebtShares, totalDebtShares - sharesToRemove, newUserDebt);
    }

    /**
     * @dev  Internal function called during 'repayAndWithdraw' external functions.
     * @param amountToWithdraw  Amount of collateral to withdraw
     * @param USGToRepay        Amount of USG to repay. When this amount is bigger than the actual debt of the user, is replaced by the real debt afterwards.
     * @return Amount of USG to burn from the sender
     */
    function _repayAndWithdraw(uint256 amountToWithdraw, uint256 USGToRepay, bool isReceiptOut) internal returns (uint256, uint256) {
        // Call _repay function in order to checkpoint the total debt, computes new User debt and burn corresponding amount of USG.
        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, uint256 newUserDebt) = _repay(msg.sender, USGToRepay);

        _updateCollatAndDebts(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebt),
            totalCollateral - amountToWithdraw,
            newUserDebtShares,
            newTotalDebtShares
        );

        _transferCollateralWithdraw(msg.sender, amountToWithdraw, isReceiptOut);

        return (USGToBurn, newUserDebtShares);
    }

    /* --------
                            LIQUIDATION
                                                    ------ */

    /**
     * @dev  Internal function called at the begining of 'liquidate', 'selfLiquidate' and 'seizeCollateral' external functions.
     *       Performs the IR checkpoint and fetch loan parameters
     * @param account   Address of the position to liquidate
     * @return LiquidatePre struct composed of :
     *   -  New index of the debt after the checkpoint
     *   -  Collateral balances of the 'account'
     *   -  Debt shares of the 'account'
     *   -  Debt updated with the new index of the 'account'
     */
    function _preLiquidate(address account) internal returns (LiquidationPre memory) {
        uint256 newDebtIndex = _checkpointIR();
        uint256 userDebtShares_ = userDebtShares[account];
        return
            LiquidationPre({
                newDebtIndex: newDebtIndex,
                collatBalance: collateralBalances[account],
                _userDebtShares: userDebtShares_,
                userDebt_: _convertToAmount(userDebtShares_, newDebtIndex, Math.Rounding.Ceil)
            });
    }

    /**
     * @dev  Internal function called during 'selfLiquidate' external function.
     * @param selfLiquidateStruct  Struct containing all variables needed for the self liquidation
     * @param liquidateCall        Contains address and bytes of the contract selling the collateral for USG
     * @return The real amount of USG to burn from the account
     */
    function _selfLiquidate(SelfLiquidateTransitionStruct memory selfLiquidateStruct, ZapStruct calldata liquidateCall) internal returns (uint256, uint256) {
        // Need to some collateral
        _verifyCollatInputNotZero(selfLiquidateStruct.selfLiquidateIn.collatAmountToLiquidate);

        // Computes the new collat balance after liquidating the collateral
        uint256 newCollatBalance = selfLiquidateStruct._collateralBalance - selfLiquidateStruct.selfLiquidateIn.collatAmountToLiquidate;
        uint256 debtSharesToRemove;
        uint256 usgToRepay = selfLiquidateStruct.selfLiquidateIn.usgToRepay;

        // Liquidate All
        if (usgToRepay >= selfLiquidateStruct.userDebt) {
            // We override USGToRepay to don't over repay
            usgToRepay = selfLiquidateStruct.userDebt;
            // As we liquidate everything, the shares to remove are all the debt shares of the position
            debtSharesToRemove = selfLiquidateStruct._userDebtShares;
        }
        // Liquidate partial
        else {
            // As it's a partial liquidation, we have to compute the amount of shares to remove that match with the USG amount to repay.
            debtSharesToRemove = _convertToShares(usgToRepay, selfLiquidateStruct.newDebtIndex, Math.Rounding.Floor);

            // In case the usgToRepay is very small, we don't want debtShares being equal to 0
            if (usgToRepay != 0) {
                require(debtSharesToRemove != 0, ZeroDebtAmount());
            }

            uint256 newUserDebt = selfLiquidateStruct.userDebt - usgToRepay;
            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation

            _verifyMinimumDebt(newUserDebt);
            // Verify that maxLTV condition is still respected
            _verifyMaxLTV(newCollatBalance, newUserDebt, false);
        }

        uint256 newUserDebtShares = selfLiquidateStruct._userDebtShares - debtSharesToRemove;

        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            msg.sender,
            newCollatBalance,
            selfLiquidateStruct._totalCollateral - selfLiquidateStruct.selfLiquidateIn.collatAmountToLiquidate,
            newUserDebtShares,
            selfLiquidateStruct._totalDebtShares - debtSharesToRemove
        );

        _postLiquidate(
            usgToRepay,
            PostLiquidate({
                collatAmountToLiquidate: selfLiquidateStruct.selfLiquidateIn.collatAmountToLiquidate,
                minUsgOut: selfLiquidateStruct.selfLiquidateIn.minUsgOut,
                maxUsgToBurn: selfLiquidateStruct.selfLiquidateIn.maxUsgToBurn,
                minCollatAmountToLiquidate: selfLiquidateStruct.selfLiquidateIn.collatAmountToLiquidate,
                isReceiptOut: selfLiquidateStruct.selfLiquidateIn.isReceiptOut
            }),
            liquidateCall
        );

        return (usgToRepay, newUserDebtShares);
    }
    /**
     * @dev  Internal function called during 'liquidate' external function.
     * @param liquidateStruct  Struct containing all variables needed for the liquidation
     * @param liquidateCall   Contains address and bytes of the contract selling the collateral for USG
     * @return The amount of collateral to liquidate
     * @return The amount of USG debt repaid
     * @return The amount of USG taken in liquidation fee
     */
    function _liquidate(LiquidateTransitionStruct memory liquidateStruct, ZapStruct calldata liquidateCall) internal returns (uint256, uint256, uint256, uint256) {
        uint256 collatAmountToLiquidate = liquidateStruct.liquidateIn.postLiquidate.collatAmountToLiquidate;
        _verifyCollatInputNotZero(collatAmountToLiquidate);

        // Prepare params as if it was a full liquidation
        uint256 debtSharesToRemove;
        uint256 usgToRepay;

        // Full liquidation
        if (collatAmountToLiquidate >= liquidateStruct._collateralBalance) {
            liquidateStruct.liquidateIn.postLiquidate.collatAmountToLiquidate = liquidateStruct._collateralBalance;
            collatAmountToLiquidate = liquidateStruct._collateralBalance;
            usgToRepay = liquidateStruct.userDebt;
            debtSharesToRemove = liquidateStruct._userDebtShares;
        }
        // Partial liquidation
        else {
            usgToRepay = (collatAmountToLiquidate * liquidateStruct.userDebt) / liquidateStruct._collateralBalance;
            debtSharesToRemove = _convertToShares(usgToRepay, liquidateStruct.newDebtIndex, Math.Rounding.Floor);
            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation
            _verifyMinimumDebt(liquidateStruct.userDebt - usgToRepay);
        }

        // Prevent small amount liquidation that doesn't remove shares
        require(debtSharesToRemove != 0, ZeroDebtAmount());

        uint256 newUserDebtShares = liquidateStruct._userDebtShares - debtSharesToRemove;
        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            liquidateStruct.liquidateIn.account,
            liquidateStruct._collateralBalance - collatAmountToLiquidate,
            liquidateStruct._totalCollateral - collatAmountToLiquidate,
            newUserDebtShares,
            liquidateStruct._totalDebtShares - debtSharesToRemove
        );

        uint256 fee;
        {
            uint256 collatValue = _mulDiv(collatAmountToLiquidate, liquidateStruct.collatPrice, 10 ** collatDecimals);
            require(collatValue >= liquidateStruct.liquidateIn.minCollatValueToLiquidate, CollatValueToLiquidateTooLow(collatValue));
            if (collatValue > usgToRepay) {
                // Fee is taken on the liquidation profits
                uint256 delta = collatValue - usgToRepay;
                fee = (liquidationFee * delta) / DENOMINATOR;
            }
        }
        _postLiquidate(usgToRepay + fee, liquidateStruct.liquidateIn.postLiquidate, liquidateCall);

        if (fee != 0) {
            _mintUSG(usg, controlTower.feeTreasury(), fee);
        }

        return (collatAmountToLiquidate, usgToRepay, fee, newUserDebtShares);
    }

    /**
     * @dev  Internal function called at the end of 'liquidate' and 'selfLiquidate' external function.
     *       Withdraw the collateral from the underlying protocol
     *       Transfer the collateral to the caller or to the zapping proxy
     *       When the collateral is sent to the zapping proxy, the 'liquidationCall' handles the selling of the collateral
     * @param usgToBurn      Amount of collateral to sell during the liquidation
     * @param postLiquidate  Struct containing :
     *                          - collatAmountToLiquidate : Amount of token to send to the liquidator
     *                          - minUsgOut : Minimum amount of USG to receive from the sell of the collateral if a router is used.
     *                          - maxUsgToBurn : Maximum amount of USG to be burnt from the caller of the function at the end of the tx.
     *                          - minAmountToLiquidate : Minimum amount of collateral to liquidate, used to protect liquidator from potential partial liquidation coming before its liquidation.
     *                          - isReceiptOut :
     * @param liquidationCall          Contains address and bytes of the contract selling the collateral for USG
     */
    function _postLiquidate(uint256 usgToBurn, PostLiquidate memory postLiquidate, ZapStruct calldata liquidationCall) internal {
        require(usgToBurn <= postLiquidate.maxUsgToBurn, MaxUSGToBurn());
        require(postLiquidate.minCollatAmountToLiquidate <= postLiquidate.collatAmountToLiquidate, MinCollatToLiquidate(postLiquidate.collatAmountToLiquidate));
        IZappingProxy _zappingProxy = zappingProxy;
        // Withdraw the collateral from the underlying protocol if needed and
        // Transfer it to the caller when there is no liquidator passed in parameter
        // If a liquidator is passed, we send the collateral to the Zapping Proxy that will handle the selling of the collateral.
        _transferCollateralWithdraw(liquidationCall.router != address(0) ? address(_zappingProxy) : msg.sender, postLiquidate.collatAmountToLiquidate, postLiquidate.isReceiptOut);
        // When liquidator is not zero, it allows to the LiquidatorProxy to receive the collateral.
        // Then, if needed, liquidator will allow the custom Liquidator to sell the collateral for USG in the same transaction.
        if (liquidationCall.router != address(0)) {
            // Block the zap liquidation with the receipt, can only be done with the collateral directly.
            require(!postLiquidate.isReceiptOut, NoZapLiquidateWithReceipt());
            _zappingProxy.zapProxy(collatToken, usg, postLiquidate.minUsgOut, msg.sender, liquidationCall);
        }

        // Burns USG from the sender.
        // The debt has to be on the caller of the transaction.
        // In case a liquidator is passed in parameter, it needs to send it back to the sender of the tx.
        _burnUSG(msg.sender, usgToBurn);
    }

    /**
     * @dev  Internal function called during 'seizeCollateral' external function.
     * @param account              Address that gets its collateral seized
     * @param _collateralBalance   Balance of collateral of the 'account'
     * @param _totalCollateral     Total collateral deposited on the market
     * @param _userDebtShares      Debt shares of the 'account'
     * @param _totalDebtShares     Total debt shares of the market
     * @param _accountDebt         Debt of the 'account'
     */
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
        _transferCollateralWithdraw(controlTower.feeTreasury(), _collateralBalance, false);
    }

    /* --------
                        LEVERAGE
                                                    ------ */

    /**
     * @dev  Internal function called during 'leverage' external function.
     * @param _collatToken       Collateral token interface
     * @param  leverageIn    Struct containing :
     *                                            - Amount of collateral to deposit, can be 0
     *                                            - Amount of USG to mint that is sold for collateral, will be incremented to userDebt.
     *                                            - Slippage, minimum amount of collatAmount to receive from the selling of USG.
     *                                            - Contract and data allowing to sell the USG for collateral.
     * @param  dumpUSGCall  Contains address and bytes of the contract to sell USG for collateral
     * @return Amount of collateral bought with the 'USGToFlashMint'
     * @return Amount of collareal to stake for the sender
     */
    function _leverage(IERC20 _collatToken, LeverageIn memory leverageIn, ZapStruct calldata dumpUSGCall) internal returns (uint256, uint256, uint256) {
        _verifyIsDepositNotPaused();
        require(isLeveragePaused == 0, LeveragePaused());

        IUSG _usg = usg;

        IZappingProxy _zappingProxy = zappingProxy;

        // Mint the USG on the Zapper, ready to be exchanged through the router
        _mintUSG(_usg, address(_zappingProxy), leverageIn.usgToFlashMint);

        // Exchange the USG that has just been minted on the Zapper for the collateral of the market
        uint256 collatBought = _zappingProxy.zapProxy(_usg, collatToken, leverageIn.minCollatAmountOut, address(this), dumpUSGCall);

        uint256 stakedAmount = leverageIn.collatToDeposit + collatBought;

        // Performs same modification as in depositAndBorrow
        uint256 newUserDebtShares = _depositAndBorrow(stakedAmount, leverageIn.usgToFlashMint, _collatToken, true);

        return (collatBought, stakedAmount, newUserDebtShares);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                     REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @dev  Internal function called during 'claimUnderlyingRewards' external function.
     *
     * @param _rewardTokens       Collateral token interface
     * @return Amount of collateral bought with the 'USGToFlashMint'
     */
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
    /**
     * @dev  Function to override to claim rewards given by the collateral
     */
    function _claimRewards() internal virtual {}

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    MIGRATE
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _verifySenderMigrator() internal view {
        require(controlTower.isPositionMigrator(msg.sender), NotAMigratoor());
    }

    function _migrateFrom(address account, uint256 collateralToRemove, uint256 debtToRemove, uint256 debtToRepay, address receiver) internal returns (uint256, uint256) {
        _verifySenderMigrator();
        uint256 newDebtIndex = _checkpointIR();

        uint256 uDebtShares = userDebtShares[account];
        uint256 debtUser = _convertToAmount(uDebtShares, newDebtIndex, Math.Rounding.Ceil);
        uint256 newCollatBalance = collateralBalances[account] - collateralToRemove;
        uint256 sharesToRemove;
        uint256 newUserDebt;

        // Debt to remove from source market is bigger than the one to repay
        require(debtToRemove >= debtToRepay, DebtToRepayTooBig());

        // All the debt is removed from marketFrom
        if (debtToRemove >= debtUser) {
            sharesToRemove = uDebtShares;
            debtToRemove = debtUser;

            // All the user debt is repaid from marketFrom
            if (debtToRepay >= debtUser) {
                debtToRepay = debtUser;
            }
        }
        // Only a part of the debt is removed from marketFrom
        else {
            sharesToRemove = _convertToShares(debtToRemove, newDebtIndex, Math.Rounding.Floor);
            newUserDebt = debtUser - debtToRemove;
            // We check both condition on minimum loan and maxLTV
            // Dont need to check them when the new user debt is equal to 0
            _verifyMinimumDebt(newUserDebt);
            _verifyMaxLTV(newCollatBalance, newUserDebt, false);
        }

        uint256 newUDebtShares = uDebtShares - sharesToRemove;
        // Update user and total debts and collaterals.
        _updateCollatAndDebts(account, newCollatBalance, totalCollateral - collateralToRemove, newUDebtShares, totalDebtShares - sharesToRemove);
        // Transfer the collateral :
        //      - Zapping proxy, if collats are different
        //      OR
        //      - Market to, if collats are the same
        _transferCollateralWithdraw(receiver, collateralToRemove, false);

        // If some debt are to repay, burn it from the caller of the migrator
        if (debtToRepay != 0) {
            _burnUSG(account, debtToRepay);
        }

        return (debtToRemove - debtToRepay, newUDebtShares);
    }

    function _migrateTo(address account, uint256 collatToAdd, uint256 debtToAdd) internal returns (uint256) {
        _verifySenderMigrator();
        if (collatToAdd != 0) {
            _verifyIsDepositNotPaused();
        }
        if (debtToAdd != 0) {
            _verifyIsBorrowNotPaused();
        }
        uint256 debtIndex = _checkpointIR();

        uint256 uDebtShares = userDebtShares[account];
        uint256 newUserDebt = _convertToAmount(uDebtShares, debtIndex, Math.Rounding.Ceil) + debtToAdd;
        uint256 newCollatBalance = collateralBalances[account] + collatToAdd;
        uint256 sharesToAdd = _convertToShares(debtToAdd, debtIndex, Math.Rounding.Ceil);
        uint256 newTotalDebtShares = totalDebtShares + sharesToAdd;
        uint256 newUserDebtShares = uDebtShares + sharesToAdd;

        // We check both condition on minimum loan and maxLTV
        // Dont need to check them when the new user debt is equal to 0
        if (newUserDebt != 0) {
            _verifyMinimumDebt(newUserDebt);
            _verifyMaxLTV(newCollatBalance, newUserDebt, false);
            _verifyDebtCap(newTotalDebtShares, debtIndex);
        }

        _updateCollatAndDebts(account, newCollatBalance, totalCollateral + collatToAdd, newUserDebtShares, newTotalDebtShares);

        _postDeposit(collatToken);

        return newUserDebtShares;
    }
}

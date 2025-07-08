// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../../interfaces/internals/USG/IControlTower.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {TokenAmount, ZapStruct, ZapStructDeposit} from "../../../interfaces/internals/ICommonStruct.sol";

import {PauseSettings} from "./PauseSettings.sol";
import {Collateral} from "./Collateral.sol";
import {ZappingUtil} from "../../Utilities/abstract/ZappingUtil.sol";

import {GlobalMarketInitParams, MarketInit, LiquidateInput, SelfLiquidateInput, IZappingProxy, IERC20} from "../../../interfaces/internals/USG/IMarketCore.sol";

/// @notice Abstract base contract implementing core functionality for USG markets.
/// @dev Inherits PauseSettings, Collateral and ZappingUtil to provide collateral management
/// Includes core logic for deposits, withdrawals, borrowing, repayment, liquidation, and leverage.
abstract contract MarketCore is PauseSettings, Collateral, ZappingUtil {
    using SafeERC20 for IERC20;
    /// @notice Reference to the ControlTower contract managing market governance and treasury.
    IControlTower public controlTower;

    /// @notice Errors to signal specific failure conditions in market operations.
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

    /// @notice Constructor marks the contract as initialized.
    constructor() {
        isInitialized = true;
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
        require(!isInitialized, AlreadyInitialized());
        isInitialized = true;

        // Core references initialization
        usg = _globalParams._USG;
        controlTower = _globalParams._controlTower;
        irCalculator = _globalParams._irCalculator;
        rewardAccumulator = _globalParams._rewardAccumulator;
        zappingProxy = _globalParams._zappingProxy;
        pauser = _globalParams._pauser;

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
        // Cannot deposit on a market with paused deposits
        require(!isDepositPaused, DepositPaused());
        // Cannot deposit 0
        require(amountDeposited != 0, ZeroCollatAmount());
        // Checkpoint the IR and indexes
        irCalculator.checkpointIR(address(this));
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
     */
    function _withdraw(uint256 amountToWithdraw) internal {
        // Checkpoint the IR and indexes
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        // Increase collateral deposited by the user
        _updateCollateral(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, _userDebt(userDebtShares[msg.sender], newDebtIndex)),
            totalCollateral - amountToWithdraw
        );

        _transferCollateralWithdraw(msg.sender, amountToWithdraw);
    }

    /**
     * @dev Computes new collateral balance after withdrawal and checks borrowing limit of maxLTV.
     * @param amountToWithdraw Amount of collateral to withdraw.
     * @param newUserDebt      New user debt of the user.
     * @return Collateral of the user post withdraw
     */
    function _getBalanceAfterWithdrawAndCheckMaxBorrowable(uint256 amountToWithdraw, uint256 newUserDebt) internal view returns (uint256) {
        // Prevent to withdraw 0 collateral from the market
        require(amountToWithdraw != 0, ZeroCollatAmount());
        // Computes the decremented collateral balance of the user after the withdraw
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        // Verify that the newDebt of the loan is not over the maximum borrrowable regarding the LTV of the position
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, UserDebtTooHigh());
        return newCollatAmount;
    }

    /**
     * @dev Hook transfering collateral to the user.
     *      When not override, transfer the collateral from the market to the user. Otherwise, refers to the overriding implementation.
     * @param to               Collateral token being deposited.
     * @param collatToWithdraw Amount of collateral to withdraw from the market.
     */
    function _transferCollateralWithdraw(address to, uint256 collatToWithdraw) internal virtual {
        collatToken.transfer(to, collatToWithdraw);
    }

    /* --------
                            BORROW 
                                                    ------ */

    /**
     * @dev  Internal function called during 'borrow', 'depositAndBorrow' and 'leverage' external functions.
     * @param receiver      Address receiving the borrowed USG.
     * @param USGToBorrow Amount of USG to borrow.
     * @param collatAmount  Amount of collateral owned by borrower.
     * @param isLeverage    Whether this borrow is part of a leverage transaction.
     * @return Updated user debt shares after borrow.
     * @return Updated total debt shares for the market.
     */
    function _borrow(address receiver, uint256 USGToBorrow, uint256 collatAmount, bool isLeverage) internal returns (uint256, uint256) {
        require(!isBorrowPaused, BorrowPaused());
        require(USGToBorrow != 0, ZeroDebtAmount());
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        uint256 _userDebtShares = userDebtShares[msg.sender];

        uint256 newUserDebt = USGToBorrow + _userDebt(_userDebtShares, newDebtIndex);

        //  Cache the new value in USG of the debt
        uint256 newUserDebtShares = (USGToBorrow * RAY) / newDebtIndex;

        uint256 newTotalDebtShares = totalDebtShares + newUserDebtShares;

        //  Verify that the new total debt is not bigger the max debt
        require(_totalDebt(badDebt, newTotalDebtShares, newDebtIndex) <= maxMarketDebt, TotalDebtTooHigh());
        //  Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, UserDebtTooLow());

        // Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(collatAmount) >= newUserDebt, UserDebtTooHigh());

        // If it's a leverage transaction, USG is already minted before
        if (!isLeverage) {
            // Mint USG to the receiver
            usg.mint(receiver, USGToBorrow);
        }

        return (_userDebtShares + newUserDebtShares, newTotalDebtShares);
    }

    /**
     * @dev  Internal function called during 'depositAndBorrow' and 'leverage' external functions.
     * @param amountDeposited Amount of collateral to deposit.
     * @param USGToBorrow   Amount of USG to borrow.
     * @param isLeverage      Whether this borrow is part of a leverage transaction.
     */
    function _depositAndBorrow(uint256 amountDeposited, uint256 USGToBorrow, IERC20 _collatToken, bool isLeverage) internal {
        require(!isDepositPaused, DepositPaused());
        // Cannot deposit 0
        require(amountDeposited != 0, ZeroCollatAmount());
        // Collat amount after the deposit
        uint256 newCollatAmount = collateralBalances[msg.sender] + amountDeposited;

        (uint256 newUserDebtShare, uint256 newTotalDebtShares) = _borrow(msg.sender, USGToBorrow, newCollatAmount, isLeverage);

        _updateCollatAndDebts(msg.sender, newCollatAmount, totalCollateral + amountDeposited, newUserDebtShare, newTotalDebtShares);

        _postDeposit(_collatToken);
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
    function _repay(address account, uint256 USGToRepay) internal returns (uint256, uint256, uint256, uint256, bool) {
        // Cannot repay 0 debt
        require(USGToRepay != 0, ZeroDebtAmount());

        // Update interests rate, computes new debt index and total debt.
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));

        uint256 _userDebtShares = userDebtShares[account];

        uint256 oldUserDebt = _userDebt(_userDebtShares, newDebtIndex);

        // Cannot repay an empty position
        require(_userDebtShares != 0, UserDebtZero());

        uint256 newUserDebtShares;
        uint256 sharesToRemove;
        uint256 newUserDebt;
        bool isFullRepay;

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
            isFullRepay = true;
        }
        // Partial repay case
        else {
            // Retrieve the real debt of the user
            newUserDebt = oldUserDebt - USGToRepay;

            sharesToRemove = (USGToRepay * RAY) / newDebtIndex;

            newUserDebtShares = _userDebtShares - sharesToRemove;

            // We need to verify that the partial repay is not decreasing the debt lower than the minimum loan.
            require(newUserDebt >= minimumLoan, UserDebtTooLow());
        }

        usg.burnFrom(msg.sender, USGToRepay);

        return (USGToRepay, newUserDebtShares, totalDebtShares - sharesToRemove, newUserDebt, isFullRepay);
    }

    /**
     * @dev  Internal function called during 'repayAndWithdraw' external functions.
     * @param amountToWithdraw  Amount of collateral to withdraw
     * @param USGToRepay      Amount of USG to repay. When this amount is bigger than the actual debt of the user, is replaced by the real debt afterwards.
     * @return Amount of USG to burn from the sender
     */
    function _repayAndWithdraw(uint256 amountToWithdraw, uint256 USGToRepay) internal returns (uint256, bool) {
        // Call _repay function in order to checkpoint the total debt, computes new User debt and burn corresponding amount of USG.
        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, uint256 newUserDebt, bool isRepayAll) = _repay(msg.sender, USGToRepay);

        _updateCollatAndDebts(
            msg.sender,
            _getBalanceAfterWithdrawAndCheckMaxBorrowable(amountToWithdraw, newUserDebt),
            totalCollateral - amountToWithdraw,
            newUserDebtShares,
            newTotalDebtShares
        );

        _transferCollateralWithdraw(msg.sender, amountToWithdraw);

        return (USGToBurn, isRepayAll);
    }

    /* --------
                            LIQUIDATION
                                                    ------ */

    /**
     * @dev  Internal function called at the begining of 'liquidate', 'selfLiquidate' and 'seizeCollateral' external functions.
     *       Performs the IR checkpoint and fetch loan parameters
     * @param account   Address of the position to liquidate
     * @return New index of the debt after the checkpoint
     * @return Collateral balances of the 'account'
     * @return Debt shares of the 'account'
     * @return Debt updated with the new index of the 'account'
     */
    function _preLiquidate(address account) internal returns (uint256, uint256, uint256, uint256) {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));
        uint256 userDebtShares_ = userDebtShares[account];
        return (newDebtIndex, collateralBalances[account], userDebtShares_, _userDebt(userDebtShares_, newDebtIndex));
    }

    /**
     * @dev  Internal function called during 'selfLiquidate' external function.
     * @param selfLiquidateCall  Struct containing all variables needed for the self liquidation
     * @param liquidateCall      Contains address and bytes of the contract selling the collateral for USG
     * @return The real amount of USG to burn from the account
     */
    function _selfLiquidate(SelfLiquidateInput memory selfLiquidateCall, ZapStruct calldata liquidateCall) internal returns (uint256, bool) {
        // Need to some collateral
        require(selfLiquidateCall.collatAmountToLiquidate != 0, ZeroCollatAmount());
        // Computes the new collat balance after liquidating the collateral
        uint256 newCollatBalance = selfLiquidateCall._collateralBalance - selfLiquidateCall.collatAmountToLiquidate;
        uint256 debtSharesToRemove;
        uint256 USGToRepay = selfLiquidateCall.USGToRepay;
        bool isRepayAll;

        // Liquidate All
        if (USGToRepay >= selfLiquidateCall.userDebt) {
            // We override USGToRepay to don't over repay
            USGToRepay = selfLiquidateCall.userDebt;
            // As we liquidate everything, the shares to remove are all the debt shares of the position
            debtSharesToRemove = selfLiquidateCall._userDebtShares;
            isRepayAll = true;
        }
        // Liquidate partial
        else {
            // As it's a partial liquidation, we have to compute the amount of shares to remove that match with the USG amount to repay.
            debtSharesToRemove = (USGToRepay * RAY) / selfLiquidateCall.newDebtIndex;

            uint256 newUserDebt = selfLiquidateCall.userDebt - USGToRepay;
            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation
            require(newUserDebt >= minimumLoan, UserDebtTooLow());
            // Verify that maxLTV condition is still respected
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

        _postLiquidate(selfLiquidateCall.collatAmountToLiquidate, USGToRepay, selfLiquidateCall.minUSGOut, liquidateCall);

        return (USGToRepay, isRepayAll);
    }

    /**
     * @dev  Internal function called during 'liquidate' external function.
     * @param liquidateInput  Struct containing all variables needed for the liquidation
     * @param liquidateCall   Contains address and bytes of the contract selling the collateral for USG
     * @return The amount of collateral to liquidate
     * @return The amount of USG debt repaid
     * @return The amount of USG taken in liquidation fee
     */
    function _liquidate(LiquidateInput memory liquidateInput, ZapStruct calldata liquidateCall) internal returns (uint256, uint256, uint256, bool) {
        uint256 collatAmountToLiquidate = liquidateInput.collatToLiquidate;
        require(liquidateInput.collatToLiquidate != 0, ZeroCollatAmount());

        uint256 debtSharesToRemove;
        uint256 USGToRepay;
        bool isRepayAll;

        // Liquidate all
        if (collatAmountToLiquidate >= liquidateInput._collateralBalance) {
            collatAmountToLiquidate = liquidateInput._collateralBalance;
            USGToRepay = liquidateInput.userDebt;
            debtSharesToRemove = liquidateInput._userDebtShares;
            isRepayAll = true;
        }
        // Liquidate partial
        else {
            USGToRepay = (collatAmountToLiquidate * liquidateInput.userDebt) / liquidateInput._collateralBalance;
            debtSharesToRemove = (USGToRepay * RAY) / liquidateInput.newDebtIndex;

            // Ensure that the remaining debt is bigger than a minimum in order to leave profitable liquidation
            require(liquidateInput.userDebt - USGToRepay >= minimumLoan, UserDebtTooLow());
        }
        // Modify the collateral balance, the user debt and the total debt
        _updateCollatAndDebts(
            liquidateInput.account,
            isRepayAll ? 0 : liquidateInput._collateralBalance - collatAmountToLiquidate,
            liquidateInput._totalCollateral - collatAmountToLiquidate,
            liquidateInput._userDebtShares - debtSharesToRemove,
            liquidateInput._totalDebtShares - debtSharesToRemove
        );

        uint256 fee = (USGToRepay * liquidationFee) / DENOMINATOR;

        _postLiquidate(collatAmountToLiquidate, USGToRepay + fee, liquidateInput.minUSGOut, liquidateCall);

        if (fee != 0) {
            usg.mint(controlTower.feeTreasury(), fee);
        }

        return (collatAmountToLiquidate, USGToRepay, fee, isRepayAll);
    }

    /**
     * @dev  Internal function called at the end of 'liquidate' and 'selfLiquidate' external function.
     *       Withdraw the collateral from the underlying protocol
     *       Transfer the collateral to the caller or to the zapping proxy
     *       When the collateral is sent to the zapping proxy, the 'liquidationCall' handles the selling of the collateral
     * @param collatAmountToLiquidate  Amount of collateral to sell during the liquidation
     * @param USGToBurn              Amount of USG to burn from the sender
     * @param minUSGOut              Slippage, Minimum amount of USG to receive after the selling of the collateral
     * @param liquidationCall          Contains address and bytes of the contract selling the collateral for USG
     */
    function _postLiquidate(uint256 collatAmountToLiquidate, uint256 USGToBurn, uint256 minUSGOut, ZapStruct calldata liquidationCall) internal {
        IZappingProxy _zappingProxy = zappingProxy;
        // Withdraw the collateral from the underlying protocol if needed and
        // Transfer it to the caller when there is no liquidator passed in parameter
        // If a liquidator is passed, we send the collateral to the Zapping Proxy that will handle the selling of the collateral.
        _transferCollateralWithdraw(liquidationCall.router != address(0) ? address(_zappingProxy) : msg.sender, collatAmountToLiquidate);
        // When liquidator is not zero, it allows to the LiquidatorProxy to receive the collateral.
        // Then, if needed, liquidator will allow the custom Liquidator to sell the collateral for USG in the same transaction.
        if (liquidationCall.router != address(0)) {
            _zappingProxy.zapProxy(collatToken, usg, minUSGOut, msg.sender, liquidationCall);
        }

        // Burns USG from the sender.
        // The debt has to be on the caller of the transaction.
        // In case a liquidator is passed in parameter, it needs to send it back to the sender of the tx.
        usg.burnFrom(msg.sender, USGToBurn);
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
        _transferCollateralWithdraw(controlTower.feeTreasury(), _collateralBalance);
    }

    /* --------
                        LEVERAGE
                                                    ------ */

    /**
     * @dev  Internal function called during 'leverage' external function.
     * @param _collatToken       Collateral token interface
     * @param collatToDeposit    Amount of collateral to deposit
     * @param USGToFlashMint   Amount of USG to add to the user debt and to sell for collateral
     * @param minCollatAmountOut Minimum amount of collat received through the selling of 'USGToFlashMint' USG
     * @param dumpUSGCall      Contains address and bytes of the contract to sell USG for collateral
     * @return Amount of collateral bought with the 'USGToFlashMint'
     * @return Amount of collareal to stake for the sender
     */
    function _leverage(
        IERC20 _collatToken,
        uint256 collatToDeposit,
        uint256 USGToFlashMint,
        uint256 minCollatAmountOut,
        ZapStruct calldata dumpUSGCall
    ) internal returns (uint256, uint256) {
        require(!isDepositPaused, DepositPaused());
        require(!isLeveragePaused, LeveragePaused());

        IUSG _usg = usg;

        IZappingProxy _zappingProxy = zappingProxy;

        // Mint the USG on the Zapper, ready to be exchanged through the router
        _usg.mint(address(_zappingProxy), USGToFlashMint);
        // Exchange the USG that has just been minted on the Zapper for the collateral of the market
        uint256 collatBought = _zappingProxy.zapProxy(_usg, collatToken, minCollatAmountOut, address(this), dumpUSGCall);

        uint256 stakedAmount = collatToDeposit + collatBought;

        // Performs same modification as in depositAndBorrow
        _depositAndBorrow(stakedAmount, USGToFlashMint, _collatToken, true);

        return (collatBought, stakedAmount);
    }

    /* --------
                        REWARDS
                                                    ------ */
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
}

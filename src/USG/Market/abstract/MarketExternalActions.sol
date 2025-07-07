// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, LiquidateInput, SelfLiquidateInput, ZapStructDeposit, IZappingProxy} from "./MarketCore.sol";

import {IMarketExternalActions} from "../../../interfaces/internals/USG/IMarketExternalActions.sol";

import {IZapper} from "../../../interfaces/internals/USG/IZapper.sol";
import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";

import {TokenAmount, ZapStruct} from "../../../interfaces/internals/ICommonStruct.sol";

/// @notice Abstract base contract exposing external user functions
/// @dev Inherits MarketCore
/// Expose deposits, withdrawals, borrowing, repayment, liquidation, and leverage functions
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    event Deposit(address indexed account, uint256 stakedAmount);
    event ZapDeposit(address indexed account, uint256 stakedAmount, IERC20 tokenIn, uint256 amountIn);

    event DepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount);
    event ZapDepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount, IERC20 tokenIn, uint256 amountIn);

    event Withdraw(address indexed account, uint256 amount);

    event RepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, bool isRepayAll);
    event ZapRepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, bool isRepayAll, IERC20 tokenIn, uint256 amountIn);

    event Borrow(address indexed account, address receiver, uint256 borrowedAmount);

    event Repay(address indexed account, address repayer, uint256 repaidAmount, bool isRepayAll);
    event ZapRepay(address indexed account, address repayer, uint256 repaidAmount, bool isRepayAll, IERC20 tokenIn, uint256 amountIn);

    event Leverage(address indexed account, uint256 stakedAmount, uint256 collatBought, uint256 borrowedAmount);
    event ZapLeverage(address indexed account, uint256 stakedAmount, uint256 collatZapDeposit, uint256 collatLeverage, uint256 borrowedAmount, IERC20 tokenIn, uint256 amountIn);

    event Liquidate(address indexed account, uint256 repaidAmount, uint256 fee, uint256 collateralLiquidated, address liquidator, bool isRepayAll);
    event SelfLiquidate(address indexed account, uint256 repaidAmount, uint256 collateralLiquidated, address liquidator, bool isRepayAll);
    event SeizeCollateral(address indexed account, uint256 newBadDebt, uint256 collateralSeized);

    error NotRewardAccumulator();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEPOSIT / BORROW 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Deposit some collateral on the market for an account.
     * @dev    Collateral is always taken from the sender. Sender needs to allow the 'collatToken' to be spent by the market.
     * @param  _for             Address for who the collateral is deposited.
     * @param  depositedAmount  Amount of collateral to deposit
     * @param  isStaked         Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function deposit(address _for, uint256 depositedAmount, bool isStaked) external nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;
        _collatToken.transferFrom(msg.sender, address(this), depositedAmount);

        uint256 stakedAmount = _depositSociabilization(depositedAmount, isStaked);
        _deposit(_for, stakedAmount, _collatToken, isStaked);

        emit Deposit(_for, stakedAmount);
    }

    /**
     * @notice Zap from a token to the collateral and deposit the collateral into the market.
     * @dev    Zaped asset is always taken from the sender. Sender needs to allow the 'asset' to be spent by the market.
     * @param  _for           Address for who the collateral is deposited.
     * @param  isStaked       Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     * @param  zapCall        Contains address and bytes of the contract selling the zapped asset to the collateral.
     */
    function zapDeposit(address _for, bool isStaked, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        uint256 stakedAmount = _depositSociabilization(collatReceived, isStaked);
        _deposit(_for, stakedAmount, _collatToken, isStaked);

        emit ZapDeposit(_for, stakedAmount, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Deposit the collateral into the market and borrow some USG.
     * @dev    Collateral is always taken from the sender. Sender needs to allow the 'collatToken' to be spent by the market.
     * @param  depositedAmount Amount of collateral to deposit
     * @param  debtBorrow      Amount of USG to borrow
     * @param  isStaked        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function depositAndBorrow(uint256 depositedAmount, uint256 debtBorrow, bool isStaked) external nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        _collatToken.transferFrom(msg.sender, address(this), depositedAmount);
        uint256 stakedAmount = _depositSociabilization(depositedAmount, isStaked);

        _depositAndBorrow(stakedAmount, debtBorrow, _collatToken, isStaked, false);

        emit DepositAndBorrow(msg.sender, stakedAmount, debtBorrow);
    }

    /**
     * @notice Zap from a token to the collateral, deposit the collateral into the market and borrow some USG.
     * @dev    Zaped asset is always taken from the sender. Sender needs to allow the 'asset' to be spent by the market.
     * @param  debtBorrow     The collateral is deposited to this address
     * @param  isStaked       Amount of collateral to deposit
     * @param  zapCall        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function zapDepositAndBorrow(uint256 debtBorrow, bool isStaked, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        uint256 stakedAmount = _depositSociabilization(collatReceived, isStaked);

        _depositAndBorrow(stakedAmount, debtBorrow, _collatToken, isStaked, false);

        emit ZapDepositAndBorrow(msg.sender, stakedAmount, debtBorrow, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Borrow some USG from the market
     * @dev    The debt is always incremented from the sender account.
     * @param  receiver       Receiver of the USG that is borrowed by the sender
     * @param  USGToBorrow  Amount of USG to mint to the receiver.
     */
    function borrow(address receiver, uint256 USGToBorrow) external nonReentrant {
        (uint256 newUserDebtShares, uint256 newTotalDebtShares) = _borrow(receiver, USGToBorrow, collateralBalances[msg.sender], false);
        _updateDebts(msg.sender, newUserDebtShares, newTotalDebtShares);

        emit Borrow(msg.sender, receiver, USGToBorrow);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REPAY / WITHDRAW 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Withdraw the collateral and send it to the caller.
     * @param  withdrawAmount Amount of collateral to withdraw
     */
    function withdraw(uint256 withdrawAmount) external nonReentrant updateRewards(msg.sender) {
        _withdraw(withdrawAmount);

        emit Withdraw(msg.sender, withdrawAmount);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @dev    When repaying fully a loan, inputing a 'USGToRepay' bigger than the user debt will repay exactly the full debt without excess.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  USGToRepay   Amount of debt to repay. This amount will be burnt.
     */
    function repayAndWithdraw(uint256 withdrawAmount, uint256 USGToRepay) external nonReentrant updateRewards(msg.sender) {
        (uint256 USGToBurn, bool isRepayAll) = _repayAndWithdraw(withdrawAmount, USGToRepay);

        emit RepayAndWithdraw(msg.sender, withdrawAmount, USGToBurn, isRepayAll);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller, zap an asset to USG and repay the whole or a part of the debt.
     * @dev
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  zapCall        Zap details
     */
    function zapRepayAndWithdraw(uint256 withdrawAmount, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        uint256 USGToRepay = _zapDeposit(zapCall, USG, msg.sender);
        (uint256 USGToBurn, bool isRepayAll) = _repayAndWithdraw(withdrawAmount, USGToRepay);

        emit ZapRepayAndWithdraw(msg.sender, withdrawAmount, USGToBurn, isRepayAll, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Repay some USG debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  USGToRepay   Amount of USG to repay
     */
    function repay(address account, uint256 USGToRepay) external nonReentrant {
        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, , bool isRepayAll) = _repay(account, USGToRepay);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit Repay(account, msg.sender, USGToBurn, isRepayAll);
    }

    /**
     * @notice Repay some USG debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  zapCall   Only used on zapAndRepay. It's the address calling the zapper and that will receive the USG during the zapping.
     */
    function zapRepay(address account, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 USGToRepay = _zapDeposit(zapCall, USG, msg.sender);

        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, , bool isRepayAll) = _repay(account, USGToRepay);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit ZapRepay(account, msg.sender, USGToBurn, isRepayAll, zapCall.tokenIn, zapCall.amountIn);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LIQUIDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Liquidate a position that have an health ratio < 1.
     * @dev    Two liquidation modes are possibles : 
     *           - Buy USG with a flashloan, repay the debt, get the collateral and do whatever you want with it.
                 - Selling the collateral for USG directly through ZappingProxy by providing a route then repay the debt and keep the difference in USG
     * @param  account             Account of the position to liquidate
     * @param  collatToLiquidate   Amount of collateral to liquidate from the position.
     * @param  minUSGOut         Minimum amount of USG to receive on the sell of the collateral. 
     * @param  liquidationCall     Contract and data allowing to sell the collateral for USG.
     */
    function liquidate(address account, uint256 collatToLiquidate, uint256 minUSGOut, ZapStruct calldata liquidationCall) external nonReentrant updateRewards(account) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(account);
        // Can liquidate only if the health ratio is below 1
        require(_healthRatio(userDebt_, collatBalance) < 1 ether, NotLiquidablePosition());

        (uint256 collatLiquidated, uint256 debtRepaid, uint256 fee, bool isRepayAll) = _liquidate(
            LiquidateInput({
                account: account,
                collatToLiquidate: collatToLiquidate,
                minUSGOut: minUSGOut,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: userDebt_
            }),
            liquidationCall
        );

        emit Liquidate(account, debtRepaid, fee, collatLiquidated, liquidationCall.router, isRepayAll);
    }

    /**
     * @notice Liquidate a part or the full collateral of the position of the caller.
     * @dev
     * @param  collatAmountToLiquidate   Amount of collateral to liquidate from the position.
     * @param  USGToRepay              Amount of debt to repay in USG after the selling of the position.
     * @param  minUSGOut               Minimum amount of USG to receive on the sell of the collateral.
     * @param  liquidationCall           Contract and data allowing to sell the collateral for USG.
     */
    function selfLiquidate(
        uint256 collatAmountToLiquidate,
        uint256 USGToRepay,
        uint256 minUSGOut,
        ZapStruct calldata liquidationCall
    ) external nonReentrant updateRewards(msg.sender) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(msg.sender);

        (uint256 debtRepaid, bool isRepayAll) = _selfLiquidate(
            SelfLiquidateInput({
                collatAmountToLiquidate: collatAmountToLiquidate,
                USGToRepay: USGToRepay,
                minUSGOut: minUSGOut,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: userDebt_
            }),
            liquidationCall
        );

        emit SelfLiquidate(msg.sender, debtRepaid, collatAmountToLiquidate, liquidationCall.router, isRepayAll);
    }

    /**
     * @notice Seize the collateral of a position where collateral value is less than the user debt.
     * @dev    Collateral is sent to dao for management and bad debt of the market is incremented with the user debt.
     * @param  account  Account of the position to seize collateral
     */
    function seizeCollateral(address account) external nonReentrant updateRewards(account) {
        // Checkpoint IR
        (, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(account);

        // Can liquidate bad debt only if the value of the collateral is below the debt
        require(_positionValue(collatBalance) < userDebt_, PositionWithoutBadDebt());

        _seizeCollateral(account, collatBalance, totalCollateral, _userDebtShares, totalDebtShares, userDebt_);

        emit SeizeCollateral(account, userDebt_, collatBalance);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LEVERAGE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Leverage the collateral amount of a position. Mint USG that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  collatToDeposit    Amount of collateral to deposit, can be 0
     * @param  USGToFlashMint   Amount of USG to mint that is sold for collateral, will be incremented to userDebt.
     * @param  minCollatAmountOut Slippage, minimum amount of collatAmount to receive from the selling of USG.
     * @param  isStaked           For markets with sociabilization mecanism prior to costly staking. When false, tx will be cheaper but a fee is taken on the collateral amount deposited.
     * @param  leverageCall       Contract and data allowing to sell the USG for collateral.
     */
    function leverage(
        uint256 collatToDeposit,
        uint256 USGToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata leverageCall
    ) external nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        if (collatToDeposit != 0) {
            // Transfer the collateral coming from the user on the market
            _collatToken.transferFrom(msg.sender, address(this), collatToDeposit);
        }

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, USGToFlashMint, minCollatAmountOut, isStaked, leverageCall);

        emit Leverage(msg.sender, stakedAmount, collatBought, USGToFlashMint);
    }

    /**
     * @notice Leverage the collateral amount of a position. Mint USG that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  USGToFlashMint   Amount of USG to mint that is sold for collateral, will be incremented to userDebt.
     * @param  minCollatAmountOut Slippage, minimum amount of collatAmount to receive from the selling of USG.
     * @param  isStaked           For markets with sociabilization mecanism prior to costly staking. When false, tx will be cheaper but a fee is taken on the collateral amount deposited.
     * @param  leverageCall       Contract and data allowing to sell the USG for collateral.
     * @param  zapDepositCall     Contract and data allowing to sell the zapToken for collateral.
     */
    function zapLeverage(
        uint256 USGToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata leverageCall,
        ZapStructDeposit calldata zapDepositCall
    ) external payable nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        uint256 collatToDeposit = _zapDeposit(zapDepositCall, _collatToken, address(this));

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, USGToFlashMint, minCollatAmountOut, isStaked, leverageCall);

        emit ZapLeverage(msg.sender, stakedAmount, collatToDeposit, collatBought, USGToFlashMint, zapDepositCall.tokenIn, zapDepositCall.amountIn);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external virtual nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());
        return _claimUnderlyingRewards(_rewardTokens);
    }
}

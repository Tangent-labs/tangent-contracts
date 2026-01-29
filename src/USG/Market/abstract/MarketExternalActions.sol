// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {
    MarketCore,
    LiquidateIn,
    LiquidateTransitionStruct,
    SelfLiquidateIn,
    SelfLiquidateTransitionStruct,
    LiquidationPre,
    ZapStructDeposit,
    LeverageIn,
    IZappingProxy
} from "./MarketCore.sol";

import {IMarketExternalActions, IControlTower} from "../../../interfaces/internals/USG/IMarketExternalActions.sol";

import {IZapper} from "../../../interfaces/internals/USG/IZapper.sol";
import {IUSG} from "../../../interfaces/internals/USG/IUSG.sol";

import {TokenAmount, ZapStruct} from "../../../interfaces/internals/ICommonStruct.sol";

/// @title MarketExternalActions
/// @author Tangent Finance
/// @notice Abstract base contract exposing external user functions
/// @dev Inherits MarketCore
/// Expose deposits, withdrawals, borrowing, repayment, liquidation, leverage and migrate functions
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    event Deposit(address indexed account, uint256 stakedAmount);
    event ZapDeposit(address indexed account, uint256 stakedAmount, IERC20 tokenIn, uint256 amountIn);

    event DepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount, uint256 debtShares);
    event ZapDepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount, uint256 debtShares, IERC20 tokenIn, uint256 amountIn);

    event Withdraw(address indexed account, uint256 amount);

    event RepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, uint256 debtShares);
    event ZapRepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, uint256 debtShares, IERC20 tokenIn, uint256 amountIn);

    event Borrow(address indexed account, address receiver, uint256 borrowedAmount, uint256 debtShares);

    event Repay(address indexed account, address repayer, uint256 repaidAmount, uint256 debtShares);
    event ZapRepay(address indexed account, address repayer, uint256 repaidAmount, uint256 debtShares, IERC20 tokenIn, uint256 amountIn);

    event Leverage(address indexed account, uint256 stakedAmount, uint256 collatBought, uint256 borrowedAmount, uint256 debtShares);
    event ZapLeverage(
        address indexed account,
        uint256 stakedAmount,
        uint256 collatZapDeposit,
        uint256 collatLeverage,
        uint256 borrowedAmount,
        uint256 debtShares,
        IERC20 tokenIn,
        uint256 amountIn
    );

    event Liquidate(address indexed account, uint256 repaidAmount, uint256 debtShares, uint256 fee, uint256 collateralLiquidated, address liquidator);
    event SelfLiquidate(address indexed account, uint256 repaidAmount, uint256 debtShares, uint256 collateralLiquidated, address liquidator);
    event SeizeCollateral(address indexed account, uint256 newBadDebt, uint256 collateralSeized);

    event MigrateFrom(address indexed account, uint256 collatRemoved, uint256 debtRemoved, uint256 debtRepaid, uint256 newUserDebtShares);
    event MigrateTo(address indexed account, uint256 collatAdded, uint256 debtAdded, uint256 newUserDebtShares);

    error NotRewardAccumulator();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEPOSIT / BORROW 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Deposit some collateral on the market for an account.
     * @dev    Collateral is always taken from the sender. Sender needs to allow the 'collatToken' to be spent by the market.
     * @param  _for             Address for who the collateral is deposited.
     * @param  depositedAmount  Amount of collateral to deposit
     * @param isReceiptIn       Choose to deposit with the receipt token or the LP.
     */
    function deposit(address _for, uint256 depositedAmount, bool isReceiptIn) external nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;

        _transferCollateralDeposit(depositedAmount, isReceiptIn);

        _deposit(_for, depositedAmount, _collatToken);

        emit Deposit(_for, depositedAmount);
    }

    /**
     * @notice Zap from a token to the collateral and deposit the collateral into the market.
     * @dev    Zaped asset is always taken from the sender. Sender needs to allow the 'asset' to be spent by the market.
     * @param  _for           Address for who the collateral is deposited.
     * @param  zapCall        Contains address and bytes of the contract selling the zapped asset to the collateral.
     */
    function zapDeposit(address _for, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        _deposit(_for, collatReceived, _collatToken);

        emit ZapDeposit(_for, collatReceived, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Deposit the collateral into the market and borrow some USG.
     * @dev    Collateral is always taken from the sender. Sender needs to allow the 'collatToken' to be spent by the market.
     * @param  depositedAmount Amount of collateral to deposit
     * @param  debtBorrow      Amount of USG to borrow
     * @param  isReceiptIn     Choose to deposit with the receipt token or the LP.
     */
    function depositAndBorrow(uint256 depositedAmount, uint256 debtBorrow, bool isReceiptIn) external nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        _transferCollateralDeposit(depositedAmount, isReceiptIn);

        uint256 debtShares = _depositAndBorrow(depositedAmount, debtBorrow, _collatToken, false);

        emit DepositAndBorrow(msg.sender, depositedAmount, debtBorrow, debtShares);
    }

    /**
     * @notice Zap from a token to the collateral, deposit the collateral into the market and borrow some USG.
     * @dev    Zaped asset is always taken from the sender. Sender needs to allow the 'asset' to be spent by the market.
     * @param  debtBorrow     The collateral is deposited to this address
     * @param  zapCall        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function zapDepositAndBorrow(uint256 debtBorrow, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        uint256 debtShares = _depositAndBorrow(collatReceived, debtBorrow, _collatToken, false);

        emit ZapDepositAndBorrow(msg.sender, collatReceived, debtBorrow, debtShares, zapCall.tokenIn, zapCall.amountIn);
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

        emit Borrow(msg.sender, receiver, USGToBorrow, newUserDebtShares);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REPAY / WITHDRAW 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Withdraw the collateral and send it to the caller.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  isReceiptOut   Choose to withdraw with the receipt token or the LP.
     */
    function withdraw(uint256 withdrawAmount, bool isReceiptOut) external nonReentrant updateRewards(msg.sender) {
        _withdraw(withdrawAmount, isReceiptOut);

        emit Withdraw(msg.sender, withdrawAmount);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @dev    When repaying fully a loan, inputing a 'usgToRepay' bigger than the user debt will repay exactly the full debt without excess.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  usgToRepay     Amount of debt to repay. This amount will be burnt.
     * @param  isReceiptOut   Choose to withdraw with the receipt token or the LP.
     */
    function repayAndWithdraw(uint256 withdrawAmount, uint256 usgToRepay, bool isReceiptOut) external nonReentrant updateRewards(msg.sender) {
        (uint256 usgToBurn, uint256 newUserDebtShares) = _repayAndWithdraw(withdrawAmount, usgToRepay, isReceiptOut);

        emit RepayAndWithdraw(msg.sender, withdrawAmount, usgToBurn, newUserDebtShares);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller, zap an asset to USG and repay the whole or a part of the debt.
     * @dev
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  isReceiptOut   Choose to withdraw with the receipt token or the LP.
     * @param  zapCall        Zap details
     */
    function zapRepayAndWithdraw(uint256 withdrawAmount, bool isReceiptOut, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        uint256 USGToRepay = _zapDeposit(zapCall, usg, msg.sender);
        (uint256 USGToBurn, uint256 newUserDebtShares) = _repayAndWithdraw(withdrawAmount, USGToRepay, isReceiptOut);

        emit ZapRepayAndWithdraw(msg.sender, withdrawAmount, USGToBurn, newUserDebtShares, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Repay some USG debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  USGToRepay   Amount of USG to repay
     */
    function repay(address account, uint256 USGToRepay) external nonReentrant {
        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, ) = _repay(account, USGToRepay);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit Repay(account, msg.sender, USGToBurn, newUserDebtShares);
    }

    /**
     * @notice Repay some usg debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  zapCall   Only used on zapAndRepay. It's the address calling the zapper and that will receive the USG during the zapping.
     */
    function zapRepay(address account, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 USGToRepay = _zapDeposit(zapCall, usg, msg.sender);

        (uint256 USGToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, ) = _repay(account, USGToRepay);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit ZapRepay(account, msg.sender, USGToBurn, newUserDebtShares, zapCall.tokenIn, zapCall.amountIn);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LIQUIDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Liquidate a position that have an health ratio < 1.
     * @dev    Two liquidation modes are possibles : 
     *           - Buy USG with a flashloan, repay the debt, get the collateral and do whatever you want with it.
                 - Selling the collateral for USG directly through ZappingProxy by providing a route then repay the debt and keep the difference in USG
     * @param  liquidateIn  Struct with parameters proper to the liquidation.
     *                         - account : Account position to liquidate
     *                         - PostLiquidateStruct : 
     *                             - collatAmountToLiquidate : Amount of collateral to liquidate from the position.   
     *                             - minUsgOut : Min USG to be returned after the swap through ZapProxy
     *                             - maxUsgToBurn : Maximum amount of USG to be burnt
     *                             - minCollatAmountToLiquidate : Minimum amount of collateral to be liquidate
     *                             - isReceiptOut : When true, receipt token is sent back to the liquidator, when false it's the underlying
     *                         - minCollatValueToLiquidat : Minimum value in dollar to liquidate
     * @param  liquidationCall  Contract and data allowing to sell the collateral for USG.
     */
    function liquidate(LiquidateIn calldata liquidateIn, ZapStruct calldata liquidationCall) external nonReentrant updateRewards(liquidateIn.account) {
        LiquidationPre memory pre = _preLiquidate(liquidateIn.account);
        uint256 collatPrice = _collateralPriceUpdate(true);

        uint256 healthRatio = MAX_UINT; // Fully healthy if no debt
        if (pre.userDebt_ != 0) {
            healthRatio = (pre.collatBalance * 10 ** (18 - collatDecimals) * collatPrice * liquidationThreshold) / (pre.userDebt_ * DENOMINATOR);
        }

        // Can liquidate only if the health ratio is below 1
        require(healthRatio < 1 ether, NotLiquidablePosition());

        (uint256 collatLiquidated, uint256 repaidDebt, uint256 fee, uint256 newUserDebtShares) = _liquidate(
            LiquidateTransitionStruct({
                liquidateIn: liquidateIn,
                collatPrice: collatPrice,
                newDebtIndex: pre.newDebtIndex,
                _collateralBalance: pre.collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: pre._userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: pre.userDebt_
            }),
            liquidationCall
        );

        emit Liquidate(liquidateIn.account, repaidDebt, newUserDebtShares, fee, collatLiquidated, liquidationCall.router);
    }

    /**
     * @notice Liquidate a part or the full collateral of the position of the caller.
     * @param  selfLiquidateIn   Parameters proper to the self liquidation
     *                             - collatAmountToLiquidate : Amount of collateral to liquidate from the position.
     *                             - usgToRepay : Amount of usg to repay, in the case this amount is bigger than the position debt, it repays the whole position.
     *                             - maxUsgToBurn : Maximum amount of USG to be burnt in total by the user.
     *                             - minUsgOut : Min USG to be returned after the swap through ZapProxy
     *                             - isReceiptOut : When true, receipt token is sent back to the position owner, when false it's the underlying
     * @param  liquidationCall   Contract and data allowing to sell the collateral for USG.
     */
    function selfLiquidate(SelfLiquidateIn calldata selfLiquidateIn, ZapStruct calldata liquidationCall) external nonReentrant updateRewards(msg.sender) {
        LiquidationPre memory pre = _preLiquidate(msg.sender);

        (uint256 repaidDebt, uint256 newUserDebtShares) = _selfLiquidate(
            SelfLiquidateTransitionStruct({
                selfLiquidateIn: selfLiquidateIn,
                newDebtIndex: pre.newDebtIndex,
                _collateralBalance: pre.collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: pre._userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: pre.userDebt_
            }),
            liquidationCall
        );

        emit SelfLiquidate(msg.sender, repaidDebt, newUserDebtShares, selfLiquidateIn.collatAmountToLiquidate, liquidationCall.router);
    }

    /**
     * @notice Seize the collateral of a position where collateral value is less than the user debt.
     * @dev    Collateral is sent to dao for management and bad debt of the market is incremented with the user debt.
     * @param  account  Account of the position to seize collateral
     */
    function seizeCollateral(address account) external nonReentrant updateRewards(account) {
        // Checkpoint IR
        LiquidationPre memory pre = _preLiquidate(account);

        // Can liquidate bad debt only if the value of the collateral is below the debt
        require(_positionValueUpdate(pre.collatBalance, true) < pre.userDebt_, PositionWithoutBadDebt());

        _seizeCollateral(account, pre.collatBalance, totalCollateral, pre._userDebtShares, totalDebtShares, pre.userDebt_);

        emit SeizeCollateral(account, pre.userDebt_, pre.collatBalance);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LEVERAGE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Leverage the collateral amount of a position. Mint USG that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  leverageIn    Struct containing :
     *                           - collatToDeposit : Amount of collateral to deposit, can be 0
     *                           - usgToFlashMint : Amount of USG to mint that is sold for collateral, will be incremented to userDebt.
     *                           - minCollatAmountOut : Slippage, minimum amount of collat to receive from the sell of USG.
     *                           - isReceiptIn :  When true, receipt token is taken from the msg.sender, when false it's the underlying.
     * @param  leverageCall  Struct containing router and data to be able to sell the USG for collateral through the ZappingProxy
     */
    function leverage(LeverageIn calldata leverageIn, ZapStruct calldata leverageCall) external nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        if (leverageIn.collatToDeposit != 0) {
            // Transfer the collateral coming from the user on the market
            _transferCollateralDeposit(leverageIn.collatToDeposit, leverageIn.isReceiptIn);
        }

        (uint256 collatBought, uint256 stakedAmount, uint256 newUserDebtShares) = _leverage(_collatToken, leverageIn, leverageCall);

        emit Leverage(msg.sender, stakedAmount, collatBought, leverageIn.usgToFlashMint, newUserDebtShares);
    }

    /**
     * @notice Leverage the collateral amount of a position. Mint USG that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  usgToFlashMint   Amount of USG to mint that is sold for collateral, will be incremented to userDebt.
     * @param  minCollatAmountOut Slippage, minimum amount of collatAmount to receive from the selling of USG.
     * @param  leverageCall       Struct containing router and data to be able to sell the USG for collateral through the ZappingProxy
     * @param  zapDepositCall     Contract and data allowing to sell the zapToken for collateral.
     */
    function zapLeverage(
        uint256 usgToFlashMint,
        uint256 minCollatAmountOut,
        ZapStruct calldata leverageCall,
        ZapStructDeposit calldata zapDepositCall
    ) external payable nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        uint256 collatToDeposit = _zapDeposit(zapDepositCall, _collatToken, address(this));

        (uint256 collatBought, uint256 stakedAmount, uint256 newUserDebtShares) = _leverage(
            _collatToken,
            LeverageIn({collatToDeposit: collatToDeposit, usgToFlashMint: usgToFlashMint, minCollatAmountOut: minCollatAmountOut, isReceiptIn: false}),
            leverageCall
        );

        emit ZapLeverage(msg.sender, stakedAmount, collatToDeposit, collatBought, usgToFlashMint, newUserDebtShares, zapDepositCall.tokenIn, zapDepositCall.amountIn);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());
        _claimRewards();
        return _claimUnderlyingRewards(_rewardTokens);
    }

    /**
     * @dev Callable only by a verified Migrator.
     *      Remove and if wanted, repay a part of the debt and withdraw a part of the collateral.
     * @param  account            Account that will be affected by the modifications
     * @param  collatToRemove     Amount of collateral to remove from the contract
     * @param  debtToRemove       Amount of debt to remove from the contract
     * @param  debtToRepay        Amount of USG to burn that will be removed from the debt transfered to the `TO` market
     * @param  receiver           Receiver of the colllateral
     */
    function migrateFrom(
        address account,
        uint256 collatToRemove,
        uint256 debtToRemove,
        uint256 debtToRepay,
        address receiver
    ) external nonReentrant updateRewards(account) returns (uint256) {
        (uint256 debtRepaid, uint256 newUserDebtShares) = _migrateFrom(account, collatToRemove, debtToRemove, debtToRepay, receiver);
        emit MigrateFrom(account, collatToRemove, debtToRemove, debtToRepay, newUserDebtShares);
        return debtRepaid;
    }

    /**
     * @dev Callable only by a verified Migrator.
     *      Received the debt from the `FROM` market and the zapped collateral.
     * @param  account        Account that will be affected by the modifications
     * @param  collatToAdd    Amount of collateral to add to the contract
     * @param  debtToAdd      Amount of debt to add to the contract
     */
    function migrateTo(address account, uint256 collatToAdd, uint256 debtToAdd) external nonReentrant updateRewards(account) {
        uint256 newUserDebtShares = _migrateTo(account, collatToAdd, debtToAdd);
        emit MigrateTo(account, collatToAdd, debtToAdd, newUserDebtShares);
    }

    /**
     * @dev Callable only by a verified Migrator.
     *      Block all the actions of the contract to prevent reentrancy exploits
     */
    function reeantrancyOn() external returns (IERC20) {
        _nonReentrantBefore();
        _verifySenderMigrator();
        return collatToken;
    }

    /**
     * @dev Callable only by a verified Migrator.
     *      Unlock all the actions of the contract.
     */
    function reeantrancyOff() external {
        _verifySenderMigrator();
        _nonReentrantAfter();
    }
}

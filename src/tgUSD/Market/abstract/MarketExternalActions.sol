// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketCore, LiquidateCall, SelfLiquidateCall, ZapStructDeposit, IZappingProxy} from "./MarketCore.sol";

import {IMarketExternalActions} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";

import {IZapper} from "../../../interfaces/internals/tgUSD/IZapper.sol";
import {ITgUSD} from "../../../interfaces/internals/tgUSD/ITgUSD.sol";

import {TokenAmount, ZapStruct} from "../../../interfaces/internals/ICommonStruct.sol";
import "forge-std/console.sol";

/// @notice
abstract contract MarketExternalActions is MarketCore, IMarketExternalActions {
    event Deposit(address indexed account, uint256 stakedAmount);
    event ZapDeposit(address indexed account, uint256 stakedAmount, IERC20 tokenIn, uint256 amountIn);

    event DepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount);
    event ZapDepositAndBorrow(address indexed account, uint256 stakedAmount, uint256 borrowedAmount, IERC20 tokenIn, uint256 amountIn);

    event Withdraw(address indexed account, uint256 amount);

    event RepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount);
    event ZapRepayAndWithdraw(address indexed account, uint256 withdrawnAmount, uint256 repaidAmount, IERC20 tokenIn, uint256 amountIn);

    event Borrow(address indexed account, address receiver, uint256 borrowedAmount);

    event Repay(address indexed account, address repayer, uint256 repaidAmount);
    event ZapRepay(address indexed account, address repayer, uint256 repaidAmount, IERC20 tokenIn, uint256 amountIn);

    event Leverage(address indexed account, uint256 stakedAmount, uint256 collatBought, uint256 borrowedAmount);
    event ZapLeverage(address indexed account, uint256 stakedAmount, uint256 collatZapDeposit, uint256 collatLeverage, uint256 borrowedAmount, IERC20 tokenIn, uint256 amountIn);

    event Liquidate(address indexed account, uint256 repaidAmount, uint256 fee, uint256 collateralLiquidated, address liquidator);
    event SelfLiquidate(address indexed account, uint256 repaidAmount, uint256 collateralLiquidated, address liquidator);
    event SeizeCollateral(address indexed account, uint256 newBadDebt, uint256 collateralSeized);

    error NotRewardAccumulator();

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function deposit(address _for, uint256 depositedAmount, bool isStaked) external nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;
        _collatToken.transferFrom(msg.sender, address(this), depositedAmount);

        uint256 stakedAmount = _depositSociabilization(depositedAmount, isStaked);
        _deposit(_for, stakedAmount);
        _postDeposit(_collatToken, isStaked);

        emit Deposit(_for, stakedAmount);
    }

    /**
     * @notice Deposit some collateral on the market for an account.
     * @param  _for            The collateral is deposited to this address
     * @param  isStaked       Amount of collateral to deposit
     * @param  zapCall        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function zapDeposit(address _for, bool isStaked, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(_for) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        uint256 stakedAmount = _depositSociabilization(collatReceived, isStaked);
        _deposit(_for, stakedAmount);
        _postDeposit(_collatToken, isStaked);

        emit ZapDeposit(_for, stakedAmount, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Deposit some collateral on the market and borrow some tgUSD.
     * @param  depositedAmount Amount of collateral to deposit
     * @param  debtBorrow      Amount of tgUSD to borrow
     * @param  isStaked        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function depositAndBorrow(uint256 depositedAmount, uint256 debtBorrow, bool isStaked) external nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        _collatToken.transferFrom(msg.sender, address(this), depositedAmount);
        uint256 stakedAmount = _depositSociabilization(depositedAmount, isStaked);

        _depositAndBorrow(msg.sender, stakedAmount, debtBorrow, false);
        _postDeposit(_collatToken, isStaked);

        emit DepositAndBorrow(msg.sender, stakedAmount, debtBorrow);
    }

    /**
     * @notice Deposit some collateral on the market for an account.
     * @param  debtBorrow            The collateral is deposited to this address
     * @param  isStaked       Amount of collateral to deposit
     * @param  zapCall        Stake or not the collateral. Cost less gas when is false but a deposit sociabilization fee is applied.
     */
    function zapDepositAndBorrow(uint256 debtBorrow, bool isStaked, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        IERC20 _collatToken = collatToken;
        uint256 collatReceived = _zapDeposit(zapCall, _collatToken, address(this));

        uint256 stakedAmount = _depositSociabilization(collatReceived, isStaked);

        _depositAndBorrow(msg.sender, stakedAmount, debtBorrow, false);
        _postDeposit(_collatToken, isStaked);

        emit ZapDepositAndBorrow(msg.sender, stakedAmount, debtBorrow, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Withdraw the collateral and send it to the caller.
     * @param  withdrawAmount Amount of collateral to withdraw
     */
    function withdraw(uint256 withdrawAmount) external nonReentrant updateRewards(msg.sender) {
        _withdraw(withdrawAmount);
        _transferCollateralWithdraw(msg.sender, withdrawAmount);

        emit Withdraw(msg.sender, withdrawAmount);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  tgUSDToRepay   Amount of debt to repay. This amount will be burnt
     */
    function repayAndWithdraw(uint256 withdrawAmount, uint256 tgUSDToRepay) external nonReentrant updateRewards(msg.sender) {
        uint256 tgUSDToBurn = _repayAndWithdraw(withdrawAmount, tgUSDToRepay);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);
        _transferCollateralWithdraw(msg.sender, withdrawAmount);

        emit RepayAndWithdraw(msg.sender, withdrawAmount, tgUSDToRepay);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  zapCall        Zap details
     */
    function zapRepayAndWithdraw(uint256 withdrawAmount, ZapStructDeposit calldata zapCall) external payable nonReentrant updateRewards(msg.sender) {
        uint256 tgUSDToRepay = _zapDeposit(zapCall, tgUSD, msg.sender);

        uint256 tgUSDToBurn = _repayAndWithdraw(withdrawAmount, tgUSDToRepay);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);

        _transferCollateralWithdraw(msg.sender, withdrawAmount);

        emit ZapRepayAndWithdraw(msg.sender, withdrawAmount, tgUSDToRepay, zapCall.tokenIn, zapCall.amountIn);
    }

    /**
     * @notice Borrow some tgUSD from the market
     * @param  receiver       Receiver of the tgUSD that is borrowed.
     * @param  tgUSDToBorrow  Amount of tgUSD to mint to the receiver.
     */
    function borrow(address receiver, uint256 tgUSDToBorrow) external nonReentrant {
        (uint256 newUserDebtShares, uint256 newTotalDebtShares) = _borrow(msg.sender, receiver, tgUSDToBorrow, collateralBalances[msg.sender], false);
        _updateDebts(msg.sender, newUserDebtShares, newTotalDebtShares);

        emit Borrow(msg.sender, receiver, tgUSDToBorrow);
    }

    /**
     * @notice Repay some tgUSD debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  tgUSDToRepay   Amount of tgUSD to repay
     */
    function repay(address account, uint256 tgUSDToRepay) external nonReentrant {
        (uint256 tgUSDToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, ) = _repay(account, tgUSDToRepay);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit Repay(account, msg.sender, tgUSDToBurn);
    }

    /**
     * @notice Repay some tgUSD debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  zapCall   Only used on zapAndRepay. It's the address calling the zapper and that will receive the tgUSD during the zapping.
     */
    function zapRepay(address account, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 tgUSDToRepay = _zapDeposit(zapCall, tgUSD, msg.sender);

        (uint256 tgUSDToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares, ) = _repay(account, tgUSDToRepay);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);

        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        emit ZapRepay(account, msg.sender, tgUSDToBurn, zapCall.tokenIn, zapCall.amountIn);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LIQUIDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Liquidate a position that have an health ratio < 1.
     * @dev    Two liquidation modes are possibles : 
     *           - Buy tgUSD with a flashloan, repay the debt, get the collateral and do whatever you want with it.
                 - Selling the collateral for tgUSD directly through ZappingProxy by providing a route then repay the debt and keep the difference in tgUSD
     * @param  account             Account of the position to liquidate
     * @param  collatToLiquidate   Amount of collateral to liquidate from the position.
     * @param  minTgUSDOut         Minimum amount of tgUSD to receive on the sell of the collateral. 
     * @param  liquidationCall     Contract and data allowing to sell the collateral for tgUSD.
     */
    function liquidate(address account, uint256 collatToLiquidate, uint256 minTgUSDOut, ZapStruct calldata liquidationCall) external nonReentrant updateRewards(account) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(account);
        // Can liquidate only if the health ratio is below 1
        require(_healthRatio(userDebt_, collatBalance) < 1 ether, NotLiquidablePosition());

        (uint256 collatLiquidated, uint256 debtRepaid, uint256 fee) = _liquidate(
            LiquidateCall({
                account: account,
                collatToLiquidate: collatToLiquidate,
                minTgUSDOut: minTgUSDOut,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: userDebt_
            }),
            liquidationCall
        );

        emit Liquidate(account, debtRepaid, fee, collatLiquidated, liquidationCall.router);
    }

    /**
     * @notice Liquidate a part or the full collateral of the position of the caller.
     * @dev
     * @param  collatAmountToLiquidate   Amount of collateral to liquidate from the position.
     * @param  tgUSDToRepay              Amount of debt to repay in tgUSD after the selling of the position.
     * @param  minTgUSDOut               Minimum amount of tgUSD to receive on the sell of the collateral.
     * @param  liquidationCall           Contract and data allowing to sell the collateral for tgUSD.
     */
    function selfLiquidate(
        uint256 collatAmountToLiquidate,
        uint256 tgUSDToRepay,
        uint256 minTgUSDOut,
        ZapStruct calldata liquidationCall
    ) external nonReentrant updateRewards(msg.sender) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(msg.sender);

        uint256 debtRepaid = _selfLiquidate(
            SelfLiquidateCall({
                collatAmountToLiquidate: collatAmountToLiquidate,
                tgUSDToRepay: tgUSDToRepay,
                minTgUSDOut: minTgUSDOut,
                newDebtIndex: newDebtIndex,
                _collateralBalance: collatBalance,
                _totalCollateral: totalCollateral,
                _userDebtShares: _userDebtShares,
                _totalDebtShares: totalDebtShares,
                userDebt: userDebt_
            }),
            liquidationCall
        );

        emit SelfLiquidate(msg.sender, debtRepaid, collatAmountToLiquidate, liquidationCall.router);
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

    /**
     * @notice Leverage the collateral amount of a position. Mint tgUSD that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  collatToDeposit    Amount of collateral to deposit, can be 0
     * @param  tgUSDToFlashMint   Amount of tgUSD to mint that is sold for collateral, will be incremented to userDebt.
     * @param  minCollatAmountOut Slippage, minimum amount of collatAmount to receive from the selling of tgUSD.
     * @param  isStaked           For markets with sociabilization mecanism prior to costly staking. When false, tx will be cheaper but a fee is taken on the collateral amount deposited.
     * @param  leverageCall       Contract and data allowing to sell the tgUSD for collateral.
     */
    function leverage(
        uint256 collatToDeposit,
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata leverageCall
    ) external nonReentrant updateRewards(msg.sender) {
        _preLeverage();

        IERC20 _collatToken = collatToken;
        if (collatToDeposit != 0) {
            // Transfer the collateral coming from the user on the market
            _collatToken.transferFrom(msg.sender, address(this), collatToDeposit);
        }

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, tgUSDToFlashMint, minCollatAmountOut, isStaked, leverageCall);

        emit Leverage(msg.sender, stakedAmount, collatBought, tgUSDToFlashMint);
    }

    /**
     * @notice Leverage the collateral amount of a position. Mint tgUSD that are fully sold for collateral on the fly.
     * @dev    The route and liquidator contract must be specified and setup properlly.
     * @param  tgUSDToFlashMint   Amount of tgUSD to mint that is sold for collateral, will be incremented to userDebt.
     * @param  minCollatAmountOut Slippage, minimum amount of collatAmount to receive from the selling of tgUSD.
     * @param  isStaked           For markets with sociabilization mecanism prior to costly staking. When false, tx will be cheaper but a fee is taken on the collateral amount deposited.
     * @param  leverageCall       Contract and data allowing to sell the tgUSD for collateral.
     * @param  zapDepositCall     Contract and data allowing to sell the zapToken for collateral.
     */
    function zapLeverage(
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata leverageCall,
        ZapStructDeposit calldata zapDepositCall
    ) external payable nonReentrant updateRewards(msg.sender) {
        _preLeverage();
        IERC20 _collatToken = collatToken;
        uint256 collatToDeposit = _zapDeposit(zapDepositCall, _collatToken, address(this));

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, tgUSDToFlashMint, minCollatAmountOut, isStaked, leverageCall);

        emit ZapLeverage(msg.sender, stakedAmount, collatToDeposit, collatBought, tgUSDToFlashMint, zapDepositCall.tokenIn, zapDepositCall.amountIn);
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

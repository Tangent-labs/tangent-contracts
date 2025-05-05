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
        (uint256 collatReceived, IERC20 _collatToken) = _zapDeposit(zapCall);
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
    function zapDepositAndBorrow(uint256 debtBorrow, bool isStaked, ZapStructDeposit calldata zapCall) external nonReentrant updateRewards(msg.sender) {
        (uint256 collatReceived, IERC20 _collatToken) = _zapDeposit(zapCall);
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
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);

        _withdrawAndRepay(withdrawAmount, tgUSDToRepay);
        _transferCollateralWithdraw(msg.sender, withdrawAmount);

        emit RepayAndWithdraw(msg.sender, withdrawAmount, tgUSDToRepay);
    }

    /**
     * @notice Withdraw the collateral, send it back to the caller and repay the whole or a part of the debt.
     * @param  withdrawAmount Amount of collateral to withdraw
     * @param  zapCall        Zap details
     */
    function zapRepayAndWithdraw(uint256 withdrawAmount, ZapStructDeposit calldata zapCall) external nonReentrant updateRewards(msg.sender) {
        uint256 tgUSDToRepay = _zapRepay(zapCall);

        _withdrawAndRepay(withdrawAmount, tgUSDToRepay);
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
        (uint256 tgUSDToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares) = _repay(account, tgUSDToRepay);
        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);

        emit Repay(account, msg.sender, tgUSDToBurn);
    }

    /**
     * @notice Repay some tgUSD debt on the market
     * @param  account        Account of the position to repay debt on.
     * @param  zapCall   Only used on zapAndRepay. It's the address calling the zapper and that will receive the tgUSD during the zapping.
     */
    function zapRepay(address account, ZapStructDeposit calldata zapCall) external payable nonReentrant {
        uint256 tgUSDToRepay = _zapRepay(zapCall);

        (uint256 tgUSDToBurn, uint256 newUserDebtShares, uint256 newTotalDebtShares) = _repay(account, tgUSDToRepay);
        _updateDebts(account, newUserDebtShares, newTotalDebtShares);

        tgUSD.burnFrom(msg.sender, tgUSDToBurn);

        emit ZapRepay(account, msg.sender, tgUSDToBurn, zapCall.tokenIn, zapCall.amountIn);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       LIQUIDATE 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _preLiquidate(address account) internal returns (uint256, uint256, uint256, uint256) {
        uint256 newDebtIndex = irCalculator.checkpointIR(address(this));
        uint256 userDebtShares_ = userDebtShares[account];
        return (newDebtIndex, collateralBalances[account], userDebtShares_, _userDebt(userDebtShares_, newDebtIndex));
    }

    //TODO Verify require on HR
    function liquidate(address account, uint256 collatToLiquidate, uint256 minTgUSDOut, ZapStruct calldata liquidationCall) external nonReentrant updateRewards(account) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(account);
        // Can liquidate only if the health ratio is below 1
        require(_healthRatio(userDebt_, collatBalance) < 1 ether, NotLiquidablePosition());

        _liquidate(
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
    }

    //TODO Verify require on maxLTV post self liquidate

    function selfLiquidate(
        uint256 collatAmountToLiquidate,
        uint256 tgUSDToRepay,
        uint256 minTgUSDOut,
        ZapStruct calldata routerCall
    ) external nonReentrant updateRewards(msg.sender) {
        (uint256 newDebtIndex, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(msg.sender);

        _selfLiquidate(
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
            routerCall
        );
    }

    function liquidateBadDebt(address account) external nonReentrant updateRewards(account) {
        // Checkpoint IR
        (, uint256 collatBalance, uint256 _userDebtShares, uint256 userDebt_) = _preLiquidate(account);

        // Can liquidate bad debt only if the value of the collateral is below the debt
        require(_positionValue(collatBalance) < userDebt_, PositionWithoutBadDebt());

        _liquidateBadDebt(account, collatBalance, totalCollateral, _userDebtShares, totalDebtShares, userDebt_);
    }

    function leverage(
        uint256 collatToDeposit,
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata dumpTgUSDCall
    ) external nonReentrant updateRewards(msg.sender) {
        _preLeverage();

        IERC20 _collatToken = collatToken;
        if (collatToDeposit != 0) {
            // Transfer the collateral coming from the user on the market
            _collatToken.transferFrom(msg.sender, address(this), collatToDeposit);
        }

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, tgUSDToFlashMint, minCollatAmountOut, isStaked, dumpTgUSDCall);

        emit Leverage(msg.sender, stakedAmount, collatBought, tgUSDToFlashMint);
    }

    function zapLeverage(
        uint256 tgUSDToFlashMint,
        uint256 minCollatAmountOut,
        bool isStaked,
        ZapStruct calldata dumpTgUSDCall,
        ZapStructDeposit calldata zapDepositCall
    ) external payable nonReentrant updateRewards(msg.sender) {
        _preLeverage();

        (uint256 collatToDeposit, IERC20 _collatToken) = _zapDeposit(zapDepositCall);

        (uint256 collatBought, uint256 stakedAmount) = _leverage(_collatToken, collatToDeposit, tgUSDToFlashMint, minCollatAmountOut, isStaked, dumpTgUSDCall);

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMarket, ItgUSD, IPriceOracle, IERC20Metadata} from "../../interfaces/internals/tgUSD/IMarket.sol";
import {ILiquidator} from "../../interfaces/internals/tgUSD/ILiquidator.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

/// @notice
abstract contract Market is Ownable, IMarket {
    using Math for uint256;
    uint256 public constant RAY = 1e27; // Facteur de précision ray (1 * 10^27)
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;

    /// @dev tgUSD is the StableCoin to borrow against the collatToken.
    ItgUSD public tgUSD;
    /// @dev Contract allowing to retrieve the price in dollar of tgUSD.
    IPriceOracle public tgUSDOracle;

    /// @dev Collateral token of the Market.
    IERC20Metadata public collatToken;
    /// @dev Contract allowing to retrieve the price in dollar of the collateral.
    IPriceOracle public collatOracle;

    address public irMinter;

    /// @dev Maxium Loan to Value of the market in %
    uint256 public maxLTV;
    /// @dev Liquidation threshold of the market in %.
    uint256 public liquidationThreshold;
    /// @dev Loan minimum in tgUSD. We need it higher on L1 to keep liquidations profitable for liquidators
    uint256 public minimumLoan;

    /// @dev Maximum debt of the market
    uint256 public maxMarketDebt;

    /// @dev
    uint256 public debtIndex;
    /// @dev Total debt of the market.
    uint256 public lastDebt;
    /// @dev Last interest rate in RAY.
    uint256 public lastIR;
    /// @dev Last time interest rate has been checkpointed.
    uint256 public blockLastIRTimestamp;
    /// @dev Total interest amount mintable by the system in tgUSD.
    uint256 public mintableInterests;

    /// @dev Amount of collateral deposited by a user.
    mapping(address => uint256) public collateralBalances;
    /// @dev Debt in amount of tgUSD per user.
    mapping(address => uint256) public positionDebtIndex;

    error TotalDebtTooHigh();
    error PositionDebtTooHigh();
    error DebtTooLow();
    error ZeroCollatAmount();
    error ZeroDebtAmount();
    error NotIRMinter();

    constructor(MarketInit memory _marketInit) Ownable(msg.sender) {
        tgUSD = _marketInit.tgUSD;
        tgUSDOracle = _marketInit.tgUSDOracle;
        collatToken = _marketInit.collatToken;
        collatOracle = _marketInit.collatOracle;
        irMinter = _marketInit.irMinter;

        maxLTV = _marketInit.maxLTV;
        liquidationThreshold = _marketInit.liquidationThreshold;
        maxMarketDebt = _marketInit.maxMarketDebt;
        minimumLoan = _marketInit.minimumLoan;

        lastIR = 10 * RAY; // 10%
        blockLastIRTimestamp = block.timestamp;

        debtIndex = RAY;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _updateCollatAndDebts(uint256 newCollatBalance, uint256 newUserDebt, uint256 newDebtIndex) internal {
        /// @dev Increase collateral deposited by the user
        collateralBalances[msg.sender] = newCollatBalance;

        /// @dev Modify
        _updateDebts(msg.sender, newUserDebt, newDebtIndex);
    }

    function _updateDebts(address account, uint256 newUserDebt, uint256 newDebtIndex) internal {
        /// @dev Recompute the new debt index of the user based on his new debt recomputed with interests and the new debtIndex
        positionDebtIndex[account] = newUserDebt.mulDiv(RAY, newDebtIndex, Math.Rounding.Floor);

        _updateGlobalDebt(newDebtIndex);
    }

    function _updateGlobalDebt(uint256 newDebtIndex) internal {
        /// @dev Update the debtIndex
        debtIndex = newDebtIndex;

        /// @dev Update the new debtIndex
        blockLastIRTimestamp = block.timestamp;
    }
    /* --------
                        DEPOSITS ACTIONS 
                                                    ------ */

    function _deposit(address _for, uint256 amountDeposited) internal {
        /// @dev Verify that newDebt is over the minimum loan
        require(amountDeposited != 0, ZeroCollatAmount());

        (uint256 newDebtIndex, ) = _checkointIR();

        _updateGlobalDebt(newDebtIndex);

        /// @dev Increase collateral deposited by the user
        collateralBalances[_for] += amountDeposited;
    }

    function _depositAndBorrow(uint256 amountDeposited, uint256 tgUSDToBorrow) internal {
        /// @dev Verify collat amount added > 0
        require(amountDeposited != 0, ZeroCollatAmount());
        require(tgUSDToBorrow != 0, ZeroDebtAmount());

        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkointIRBorrow(tgUSDToBorrow);
        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToBorrow;
        uint256 newCollatAmount = collateralBalances[msg.sender] + amountDeposited;

        /// @dev Verify that the new total debt is not bigger the max debt
        require(newTotalDebt < maxMarketDebt, TotalDebtTooHigh());
        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());
        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, PositionDebtTooHigh());

        _updateCollatAndDebts(newCollatAmount, newUserDebt, newDebtIndex);
        /// @dev Mint tgUSD to the user
        tgUSD.mint(msg.sender, tgUSDToBorrow);
    }

    function _depositAndRepay(address _for, uint256 amountDeposited, uint256 tgUSDToRepay) internal {
        /// @dev Verify collat amount added > 0
        require(amountDeposited != 0, ZeroCollatAmount());
        require(tgUSDToRepay != 0, ZeroDebtAmount());

        (uint256 newDebtIndex, ) = _checkointIRRepay(tgUSDToRepay);
        uint256 newUserDebt = _positionDebt(_for, newDebtIndex) - tgUSDToRepay;

        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());

        /// @dev Cache the new value in tgUSD of the debt
        _updateCollatAndDebts(collateralBalances[_for] + amountDeposited, newUserDebt, newDebtIndex);
        /// @dev Burns tgUSD from the user
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);
    }

    /* --------
                        WITHDRAW ACTIONS 
                                                    ------ */

    function _withdraw(uint256 amountToWithdraw) internal {
        require(amountToWithdraw != 0, ZeroCollatAmount());

        (uint256 newDebtIndex, ) = _checkointIR();

        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;
        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(newCollatAmount) >= _positionDebt(msg.sender, newDebtIndex), PositionDebtTooHigh());

        _updateGlobalDebt(newDebtIndex);

        /// @dev Increase collateral deposited by the user
        collateralBalances[msg.sender] = newCollatAmount;
    }

    function _withdrawAndBorrow(uint256 amountToWithdraw, uint256 tgUSDToBorrow) internal {
        require(amountToWithdraw != 0, ZeroCollatAmount());
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkointIRBorrow(tgUSDToBorrow);

        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToBorrow;
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        /// @dev Verify that the new total debt is not bigger the max debt
        require(newTotalDebt < maxMarketDebt, TotalDebtTooHigh());
        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());
        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable

        require(_maxBorrowable(newCollatAmount) >= newUserDebt, PositionDebtTooHigh());

        _updateCollatAndDebts(newCollatAmount, newUserDebt, newDebtIndex);

        /// @dev Mint tgUSD to the user
        tgUSD.mint(msg.sender, tgUSDToBorrow);
    }

    function _withdrawAndRepay(uint256 amountToWithdraw, uint256 tgUSDToRepay) internal {
        require(amountToWithdraw != 0, ZeroCollatAmount());
        require(tgUSDToRepay != 0, ZeroDebtAmount());

        (uint256 newDebtIndex, ) = _checkointIRRepay(tgUSDToRepay);

        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToRepay;
        uint256 newCollatAmount = collateralBalances[msg.sender] - amountToWithdraw;

        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());
        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(newCollatAmount) >= newUserDebt, PositionDebtTooHigh());

        _updateCollatAndDebts(newCollatAmount, newUserDebt, newDebtIndex);

        /// @dev Mint tgUSD to the user
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);
    }

    /* --------
                    BORROW/REPAY ACTIONS 
                                                    ------ */

    function borrow(address receiver, uint256 tgUSDToBorrow) external {
        require(tgUSDToBorrow != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, uint256 newTotalDebt) = _checkointIRBorrow(tgUSDToBorrow);

        /// @dev Cache the new value in tgUSD of the debt
        uint256 newUserDebt = _positionDebt(msg.sender, newDebtIndex) + tgUSDToBorrow;

        /// @dev Verify that the new total debt is not bigger the max debt
        require(newTotalDebt < maxMarketDebt, TotalDebtTooHigh());
        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());

        /// @dev Verify that the newDebt of the loan is not over the maximum borrrowable
        require(_maxBorrowable(msg.sender) >= newUserDebt, PositionDebtTooHigh());

        _updateDebts(msg.sender, newUserDebt, newDebtIndex);

        /// @dev Mint tgUSD to the user
        tgUSD.mint(receiver, tgUSDToBorrow);
    }

    function repay(address account, uint256 tgUSDToRepay) external {
        require(tgUSDToRepay != 0, ZeroDebtAmount());
        (uint256 newDebtIndex, ) = _checkointIRRepay(tgUSDToRepay);

        /// @dev Cache the new value in tgUSD of the debt
        uint256 newUserDebt = _positionDebt(account, newDebtIndex) - tgUSDToRepay;

        /// @dev Verify that newDebt is over the minimum loan
        require(newUserDebt >= minimumLoan, DebtTooLow());

        _updateDebts(account, newUserDebt, newDebtIndex);

        /// @dev Mint tgUSD from the user
        tgUSD.burnFrom(msg.sender, tgUSDToRepay);
    }

    function repayAll(address account) external {
        uint256 userDebt = positionDebt(account);

        (uint256 newDebtIndex, ) = _checkointIRRepay(userDebt);

        _updateDebts(account, 0, newDebtIndex);

        /// @dev Mint tgUSD from the user
        tgUSD.burnFrom(msg.sender, userDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEBT & IR CHECKPOINTS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function mintPendingInterests() external returns (uint256) {
        require(msg.sender == irMinter, NotIRMinter());
        (uint256 newDebtIndex, ) = _checkointIR();

        _updateGlobalDebt(newDebtIndex);

        uint256 _mintableIterests = mintableInterests;
        delete mintableInterests;
        return _mintableIterests;
    }

    function _indexIncrease(uint256 timeDelta) internal view returns (uint256) {
        uint256 _lastIr = lastIR;

        if (_lastIr != 0) {
            return _lastIr.mulDiv(timeDelta, 36500 days, Math.Rounding.Floor);
        } else {
            return 0;
        }
    }

    function _updateInterests() internal returns (uint256, uint256) {
        /// @dev Time elapsed betw
        uint256 timeDelta = block.timestamp - blockLastIRTimestamp;
        uint256 newTotalDebt = lastDebt;
        uint256 newDebtIndex = debtIndex;

        if (timeDelta != 0) {
            uint256 coeffIncrease = _indexIncrease(timeDelta);
            newDebtIndex += coeffIncrease;

            uint256 interestsGenerated = (newTotalDebt * coeffIncrease) / RAY;

            mintableInterests += interestsGenerated;

            newTotalDebt += interestsGenerated;
        }

        return (newDebtIndex, newTotalDebt);
    }

    function _checkointIR() internal returns (uint256, uint256) {
        (uint256 _debtIndex, uint256 newTotalDebt) = _updateInterests();

        lastDebt = newTotalDebt;

        return (_debtIndex, newTotalDebt);
    }

    function _checkointIRBorrow(uint256 debt) internal returns (uint256, uint256) {
        (uint256 _debtIndex, uint256 newTotalDebt) = _updateInterests();

        lastDebt = newTotalDebt + debt;

        return (_debtIndex, newTotalDebt);
    }

    function _checkointIRRepay(uint256 debt) internal returns (uint256, uint256) {
        (uint256 _debtIndex, uint256 newTotalDebt) = _updateInterests();

        lastDebt = newTotalDebt - debt;

        return (_debtIndex, newTotalDebt);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        GLOBAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function totalDebt() public view returns (uint256) {
        uint256 _lastDebt = lastDebt;
        return _lastDebt + _pendingInterests(_lastDebt);
    }
    function pendingInterests() public view returns (uint256) {
        return (lastDebt * _indexIncrease(block.timestamp - blockLastIRTimestamp)) / RAY;
    }

    function _pendingInterests(uint256 _lastDebt) public view returns (uint256) {
        return (_lastDebt * _indexIncrease(block.timestamp - blockLastIRTimestamp)) / RAY;
    }

    function maxBorrowable(uint256 collatAmount) external view returns (uint256) {
        return _maxBorrowable(collatAmount);
    }

    function _maxBorrowable(uint256 collatAmount) internal view returns (uint256) {
        return (maxLTV * _collateralValue(collatAmount)) / DENOMINATOR;
    }

    function _collateralPrice() internal view returns (uint256) {
        return collatOracle.latestAnswer();
    }

    function _collateralValue(uint256 collatAmount) internal view returns (uint256) {
        return (collatAmount * _collateralPrice()) / 1 ether;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USERS VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function positionDebt(address account) public view returns (uint256) {
        uint256 newDebtIndex = debtIndex + _indexIncrease(block.timestamp - blockLastIRTimestamp);
        return _positionDebt(account, newDebtIndex);
    }

    function healthRatio(address account) public view returns (uint256) {
        return _healthRatio(account);
    }

    function _healthRatio(address account) internal view returns (uint256) {
        if (positionDebt(account) != 0) {
            return (collateralBalances[account] * _collateralPrice() * liquidationThreshold) / (positionDebt(account) * DENOMINATOR);
        }
        return MAX_UINT;
    }

    function liquidationPrice(address account) public view returns (uint256) {
        return ((positionDebt(account) * DENOMINATOR) * 1e18) / (collateralBalances[account] * liquidationThreshold);
    }

    function _maxBorrowable(address account) internal view returns (uint256) {
        return (maxLTV * _collateralValue(account)) / DENOMINATOR;
    }

    function _positionDebt(address account, uint256 newDebtIndex) internal view returns (uint256) {
        return positionDebtIndex[account].mulDiv(newDebtIndex, RAY, Math.Rounding.Floor);
    }

    function _collateralValue(address account) internal view returns (uint256) {
        return (collateralBalances[account] * _collateralPrice()) / 1 ether;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    // function _liquidate(address account, ILiquidator liquidator) internal {
    //     require(_healthRatio(account) <= liquidationThreshold);

    //     ItgUSD _tgUSD = tgUSD;
    //     uint256 tgUSDBalance = _tgUSD.balanceOf(address(this));

    //     ///@dev Give collatera to liquidator
    //     collatToken.transfer(address(liquidator), collaterals[account]);
    //     liquidator.sendDebt();

    //     require(_tgUSD.balanceOf(address(this)) - tgUSDBalance>= )
    // }
}

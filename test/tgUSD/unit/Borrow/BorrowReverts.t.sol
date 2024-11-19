// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract BorrowReverts is ConvexCurveContext {
    MarketNoRewards public market;
    IERC20Metadata public collatToken;

    HDepositNoRewards public hDeposit;
    HBorrow public hBorrow;

    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        collatToken = AddrClassicERC20.TOKEN_SDAI;
        market = deployNoRewardsMarket(collatToken);

        hDeposit = new HDepositNoRewards(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();

        maxMarketDebt = market.maxMarketDebt();
    }

    function test_borrow_0_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.borrow(usr1, 0);
    }

    function test_borrow_more_than_max_total_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.TotalDebtTooHigh.selector));
        market.borrow(usr1, maxMarketDebt + 1);
    }

    function test_borrow_less_than_minimum_loan() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooLow.selector));
        market.borrow(usr1, minimumLoan - 1);
    }

    function test_borrow_with_0_collateral() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooHigh.selector));
        market.borrow(usr1, minimumLoan);
    }

    function test_borrow_more_than_LTV_with_not_enough_collat() external {
        hDeposit.deposit(usr1, minimumLoan * 3, false);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooHigh.selector));
        market.borrow(usr1, market.maxBorrowable(usr1) + 1);
        vm.stopPrank();
    }
}

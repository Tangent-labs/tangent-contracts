// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract BorrowReverts is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;

    ConvexCrvLPMarket public market;
    HDepositConvexCrvLP public hDeposit;
    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
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
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooLow.selector));
        market.borrow(usr1, minimumLoan - 1);
    }

    function test_borrow_with_0_collateral() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.borrow(usr1, minimumLoan);
    }

    function test_borrow_more_than_LTV_with_not_enough_collat() external {
        hDeposit.deposit(usr1, 3 ether, false);
        uint256 maxBorrow = market.maxBorrowable(usr1);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.borrow(usr1, maxBorrow + 1);
        vm.stopPrank();
    }
}

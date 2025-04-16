// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract DepositAndBorrowReverts is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;

    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        collatToken = AddrCurveStableLP.PXETH_WETH;
        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();

        maxMarketDebt = market.maxMarketDebt();
    }

    function test_depositBorrow_amountDeposited_0() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.depositAndBorrow(0, 1_000 ether, false, address(0));
    }

    function test_depositBorrow_amountDeposited_very_low() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.depositAndBorrow(0, 1_000 ether, false, address(0));
    }

    function test_depositBorrow_0_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.depositAndBorrow(2 ether, 0, false, address(0));
    }

    function test_depositBorrow_more_than_max_total_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.TotalDebtTooHigh.selector));
        market.depositAndBorrow(2 ether, maxMarketDebt + 1, false, address(0));
    }

    function test_depositBorrow_less_than_minimum_loan() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooLow.selector));
        market.depositAndBorrow(2 ether, minimumLoan - 1, false, address(0));
    }

    function test_depositBorrow_more_than_LTV_with_not_enough_collat() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.depositAndBorrow(0.5 ether, minimumLoan, false, address(0));
        vm.stopPrank();
    }
}

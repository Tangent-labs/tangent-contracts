// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract DepositAndBorrowReverts is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;

    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        collatToken = AddrCurveStableLP.WETH_pxETH;
        market = deployConvexCurveLPMarket(collatToken, true);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();

        maxMarketDebt = market.maxMarketDebt();

        vm.prank(usr1);
        collatToken.approve(address(market), MAX_UINT);
    }

    function test_depositBorrow_amountDeposited_0() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.depositAndBorrow(0, 1_000 ether, false);
    }

    function test_depositBorrow_amountDeposited_very_low() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.depositAndBorrow(0, 1_000 ether, false);
    }

    function test_depositBorrow_0_debt() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.depositAndBorrow(2 ether, 0, false);
    }

    function test_depositBorrow_more_than_max_total_debt() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.TotalDebtTooHigh.selector));
        market.depositAndBorrow(4_000 ether, maxMarketDebt + 1, false);
    }

    function test_depositBorrow_less_than_minimum_loan() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooLow.selector));
        market.depositAndBorrow(2 ether, minimumLoan - 1, false);
    }

    function test_depositBorrow_more_than_LTV_with_not_enough_collat() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.depositAndBorrow(0.5 ether, minimumLoan, false);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract DepositAndBorrowReverts is ConvexCurveContext {
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

    function test_depositBorrow_amountDeposited_0() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.depositAndBorrow(usr1, 0, 1_000 ether, false);
    }

    function test_depositBorrow_0_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.depositAndBorrow(usr1, 1_000 ether, 0, false);
    }

    function test_depositBorrow_more_than_max_total_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.TotalDebtTooHigh.selector));
        market.depositAndBorrow(usr1, 1_000 ether, maxMarketDebt + 1, false);
    }

    function test_depositBorrow_less_than_minimum_loan() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooLow.selector));
        market.depositAndBorrow(usr1, 100 ether, minimumLoan - 1, false);
    }

    function test_depositBorrow_more_than_LTV_with_not_enough_collat() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooHigh.selector));
        market.depositAndBorrow(usr1, 100 ether, minimumLoan, false);
        vm.stopPrank();
    }
}

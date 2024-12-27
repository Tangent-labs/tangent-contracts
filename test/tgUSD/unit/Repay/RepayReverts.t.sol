// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Features/BorrowRepay/HRepay.sol";

contract RepayReverts is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;
    HRepay public hRepay;

    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        collatToken = AddrERC4626.S_DAI;
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        minimumLoan = market.minimumLoan();
        maxMarketDebt = market.maxMarketDebt();
    }

    function test_repay_0_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.repay(usr1, 0, address(0));
    }

    function test_repay_account_without_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtZero.selector));
        market.repay(usr1, 10000, address(0));
    }

    function test_repay_and_leave_position_under_minimum_loan() external {
        hDeposit.depositAndBorrow(10_000 ether, 3_000 ether, true, address(0));
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooLow.selector));
        market.repay(usr1, 1, address(0));
    }
}

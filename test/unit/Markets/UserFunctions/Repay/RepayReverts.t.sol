// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract RepayReverts is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;
    HRepay public hRepay;

    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        collatToken = AddrCurveStableLP.WETH_frxETH;
        market = deployConvexCurveLPMarket(collatToken, true);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        minimumLoan = market.minimumLoan();
        maxMarketDebt = market.maxMarketDebt();
    }

    function test_repay_0_debt() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroDebtAmount.selector));
        market.repay(usr1, 0);
    }

    function test_repay_account_without_debt() external {
        deal(address(usg), usr1, 1000);
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtZero.selector));
        market.repay(usr1, 1000);
    }

    function test_repay_and_leave_position_under_minimum_loan() external {
        deal(address(usg), usr1, 1);
        hDeposit.depositAndBorrow(10_000 ether, 3_000 ether, true);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooLow.selector));
        market.repay(usr1, 1);
    }
}

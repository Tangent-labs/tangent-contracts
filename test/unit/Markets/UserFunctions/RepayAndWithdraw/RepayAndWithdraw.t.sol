// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract RepayAndWithdraw is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 depositedAmount = 100_000 ether;
    uint256 debtBorrow = 70_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.sUSDS_USDT;
        market = deployConvexCurveLPMarket(collatToken, false);

        vm.startPrank(usr1);
        deal(address(collatToken), usr1, 100_000 ether);
        collatToken.approve(address(market), MAX_UINT);

        market.depositAndBorrow(depositedAmount, debtBorrow, true);
    }

    function test_repayAndWithdraw_fully() external {
        verifyReceiveERC20(collatToken, usr1, depositedAmount);
        verifyLostERC20(tgUSD, usr1, debtBorrow);

        market.repayAndWithdraw(depositedAmount, MAX_UINT);

        assertEq(0, market.userDebt(usr1));
        assertEq(0, market.collateralBalances(usr1));
        assertERC20Tracking();
    }

    function test_repayAndWithdraw_partial() external {
        verifyReceiveERC20(collatToken, usr1, depositedAmount / 2);
        verifyLostERC20(tgUSD, usr1, debtBorrow / 2);

        market.repayAndWithdraw(depositedAmount / 2, debtBorrow / 2);

        assertEq(depositedAmount / 2, market.collateralBalances(usr1));
        assertEq(debtBorrow / 2, market.userDebt(usr1));
        assertERC20Tracking();
    }

    function test_repayAndWithdraw_fails_when_0_amount_to_withdraw_in_parameter() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.repayAndWithdraw(0, debtBorrow / 2);
    }

    function test_repayAndWithdraw_fails_when_LTV_is_too_small() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.repayAndWithdraw(depositedAmount - 1, debtBorrow / 2);
    }

    function test_repayAndWithdraw_fails_when_debt_is_left_with_less_than_minimum() external {
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.repayAndWithdraw(depositedAmount - 1, debtBorrow / 2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract SgUSDDeposit is ConvexCurveContext {
    function test_deposit_sgUSD() external {
        vm.startPrank(owner);
        // Deposit Limit
        sgUSD.add_role(owner, 256);
        // Set reward processor
        sgUSD.add_role(owner, 32);
        // sgUSD.add_role(address(sgUSD), 32);

        sgUSD.set_deposit_limit(MAX_UINT);
        // sgUSD.setProfitMaxUnlockTime(1 days);
        vm.stopPrank();

        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(tgUSD), usr1, amountIn);
        tgUSD.approve(address(sgUSD), MAX_UINT);

        sgUSD.deposit(amountIn, usr1);

        deal(address(tgUSD), usr1, amountIn);

        tgUSD.transfer(address(sgUSD), amountIn);

        assertEq(sgUSD.fullProfitUnlockDate(), 0, "Full profit unlock date not correct");
        assertEq(sgUSD.profitUnlockingRate(), 0, "Profit unlock rate");
        assertEq(sgUSD.profitMaxUnlockTime(), 7 days, "Profit Max unlock time not correct");

        assertEq(sgUSD.totalIdle(), amountIn, "Total Idle is correct");
        assertEq(sgUSD.deposit_limit(), MAX_UINT, "Deposit limit is corect");
        vm.stopPrank();

        vm.prank(owner);
        sgUSD.process_report(address(sgUSD));

        vm.startPrank(usr1);
        assertEq(sgUSD.pricePerShare(), 1 ether, "Price per share is still 1");

        skip(3 days);

        assertEq(sgUSD.pricePerShare(), 1272727272727272727, "Total Idle is correct");

        skip(4 days);

        assertEq(sgUSD.pricePerShare(), 2 ether, "Total Idle is correct");
        // sgUSD.process_report(address(sgUSD));
        assertEq(sgUSD.maxWithdraw(usr1), 20_000 ether, "tchoin");

        verifyReceiveERC20(tgUSD, usr1, 20_000 ether, "tgUSD received");
        verifyLostERC20(IERC20(address(sgUSD)), usr1, 10_000 ether, "sgUSD lost");
        verifyBurnERC20(IERC20(address(sgUSD)), 10_000 ether, "sgUSD burnt");

        sgUSD.redeem(10_000 ether, usr1, usr1);
        assertERC20Tracking();
    }
}

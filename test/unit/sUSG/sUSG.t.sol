// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract sUSGDeposit is MarketDeploymentContext {
    function test_deposit_sUSG() external {
        vm.startPrank(owner);
        // Deposit Limit
        sUSG.add_role(owner, 256);
        // Set reward processor
        sUSG.add_role(owner, 32);
        // sUSG.add_role(address(sUSG), 32);

        sUSG.set_deposit_limit(MAX_UINT);
        // sUSG.setProfitMaxUnlockTime(1 days);
        vm.stopPrank();

        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(usg), usr1, amountIn);
        usg.approve(address(sUSG), MAX_UINT);

        sUSG.deposit(amountIn, usr1);

        deal(address(usg), usr1, amountIn);

        usg.transfer(address(sUSG), amountIn);

        vm.stopPrank();

        vm.prank(owner);
        sUSG.process_report(address(sUSG));

        vm.startPrank(usr1);
        assertEq(sUSG.pricePerShare(), 1 ether, "Price per share is still 1");

        skip(3 days);

        assertEq(sUSG.pricePerShare(), 1264705882352941176, " Price per share");

        skip(4 days);

        assertEq(sUSG.pricePerShare(), 1954545454545454545, "Price per share");
        // sUSG.process_report(address(sUSG));
        assertEq(sUSG.maxWithdraw(usr1), 19545454545454545454545, "Maximum to withdraw");

        verifyReceiveERC20(usg, usr1, 19545454545454545454545, "usg received");
        verifyLostERC20(IERC20(address(sUSG)), usr1, 10_000 ether, "sUSG lost");
        verifyBurnERC20(IERC20(address(sUSG)), 10_000 ether, "sUSG burnt");

        sUSG.redeem(10_000 ether, usr1, usr1);
        assertERC20Tracking();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol"; // <-- for Vm.Log

contract sUSGDeposit is MarketDeploymentContext {
    bytes32 STRATEGY_REPORTED_SIG = keccak256("StrategyReported(address,uint256,uint256,uint256,uint256,uint256,uint256)");
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

    function test_deposit_sUSG_logs() external {
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
        vm.recordLogs();
        uint256 debtBefore = 0;
        //sUSG.strategies(address(sUSG));
        sUSG.process_report(address(sUSG));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;

        for (uint i; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == STRATEGY_REPORTED_SIG) {
                found = true;
                address strategy = address(uint160(uint256(logs[i].topics[1])));
                assertEq(strategy, address(sUSG), "strategy");

                (uint256 gain, uint256 loss, uint256 currentDebtAfter, uint256 protocolFees, uint256 totalFees, uint256 totalRefunds) = abi.decode(
                    logs[i].data,
                    (uint256, uint256, uint256, uint256, uint256, uint256)
                );

                // no accountant set => fees/refunds zero
                assertEq(loss, 0, "loss should be 0");
                assertEq(protocolFees, 0, "protocolFees should be 0");
                assertEq(totalFees, 0, "totalFees should be 0");
                assertEq(totalRefunds, 0, "totalRefunds should be 0");
                assertGt(gain, 0, "gain should be greater than 0");

                // assertEq(currentDebtAfter, debtBefore + gain - loss, "currentDebt_after must equal debtBefore + gain - loss");
                break;
            }
        }

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

    function test_StrategyReported_two_deposits_with_gains() external {
        vm.startPrank(owner);
        // Deposit Limit
        sUSG.add_role(owner, 256);
        // Set reward processor
        sUSG.add_role(owner, 32);
        sUSG.set_deposit_limit(MAX_UINT);
        vm.stopPrank();

        vm.startPrank(usr1);
        uint256 firstDeposit = 10_000 ether;
        deal(address(usg), usr1, firstDeposit);
        usg.approve(address(sUSG), MAX_UINT);
        sUSG.deposit(firstDeposit, usr1);
        console.log("First deposit:", firstDeposit / 10 ** 18);

        // Transfer additional USG to simulate gains for first deposit
        deal(address(usg), usr1, firstDeposit);
        usg.transfer(address(sUSG), firstDeposit);
        vm.stopPrank();

        // First process_report
        vm.prank(owner);
        vm.recordLogs();
        sUSG.process_report(address(sUSG));
        Vm.Log[] memory firstLogs = vm.getRecordedLogs();

        // Extract gain from first report
        uint256 firstGain = 0;
        for (uint i; i < firstLogs.length; i++) {
            if (firstLogs[i].topics.length > 0 && firstLogs[i].topics[0] == STRATEGY_REPORTED_SIG) {
                (uint256 gain, uint256 loss, uint256 currentDebtAfter, uint256 protocolFees, uint256 totalFees, uint256 totalRefunds) = abi.decode(
                    firstLogs[i].data,
                    (uint256, uint256, uint256, uint256, uint256, uint256)
                );
                console.log("firstLogs currentDebtAfter", currentDebtAfter / 10 ** 18);
                console.log("firstLogs gain", gain / 10 ** 18);
                console.log("firstLogs totalRefunds", totalRefunds / 10 ** 18);
                console.log("firstLogs loss", loss / 10 ** 18);
                console.log("firstLogs protocolFees", protocolFees / 10 ** 18);
                console.log("firstLogs totalFees", totalFees / 10 ** 18);
                firstGain = gain;
                break;
            }
        }

        console.log("First gain:", firstGain / 10 ** 18);

        // Wait 3 days to accumulate more gains
        skip(3 days);
        console.log("skip 3 days:");

        // Second deposit
        vm.startPrank(usr1);
        uint256 secondDeposit = 5_000 ether;
        deal(address(usg), usr1, secondDeposit);
        sUSG.deposit(secondDeposit, usr1);
        console.log("Second deposit:", secondDeposit / 10 ** 18);

        // Transfer additional USG to simulate gains for second deposit
        deal(address(usg), usr1, secondDeposit);
        usg.transfer(address(sUSG), secondDeposit);
        vm.stopPrank();

        // Second process_report
        vm.prank(owner);
        vm.recordLogs();
        sUSG.process_report(address(sUSG));
        Vm.Log[] memory secondLogs = vm.getRecordedLogs();

        // Extract gain from second report
        uint256 secondGain = 0;
        for (uint i; i < secondLogs.length; i++) {
            if (secondLogs[i].topics.length > 0 && secondLogs[i].topics[0] == STRATEGY_REPORTED_SIG) {
                (uint256 gain, uint256 loss, uint256 currentDebtAfter, uint256 protocolFees, uint256 totalFees, uint256 totalRefunds) = abi.decode(
                    secondLogs[i].data,
                    (uint256, uint256, uint256, uint256, uint256, uint256)
                );
                console.log("secondLogs currentDebtAfter", currentDebtAfter / 10 ** 18);
                console.log("secondLogs gain", gain / 10 ** 18);
                console.log("secondLogs totalRefunds", totalRefunds / 10 ** 18);
                console.log("secondLogs loss", loss / 10 ** 18);
                console.log("secondLogs protocolFees", protocolFees / 10 ** 18);
                console.log("secondLogs totalFees", totalFees / 10 ** 18);
                secondGain = gain;
                break;
            }
        }

        console.log("Second gain:", secondGain / 10 ** 18);

        assertEq(secondGain, secondDeposit);
        assertEq(firstGain, firstDeposit);
    }
}

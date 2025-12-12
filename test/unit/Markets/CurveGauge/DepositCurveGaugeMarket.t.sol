// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract DepositCurveGaugeMarket is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    CurveGaugeMarket public market;
    IGauge public gaugeToken;
    IERC20Metadata public collatToken;
    uint256 amountIn = 10_000 ether;

    function setUp() public {
        gaugeToken = AddrCurveGauge.PYUSD_USDC;
        collatToken = AddrCurveStableLP.PYUSD_USDC;
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = AddrClassicERC20.PYUSD;
        tokens[1] = AddrClassicERC20.CRV;
        market = deployCurveGaugeMarket(collatToken, tokens);
    }

    function test_deposit_with_lp_and_repayWithdraw_with_gauge_token() external {
        vm.startPrank(usr1);

        collatToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(collatToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(gaugeToken, address(market), amountIn, "Gauge received by Market");

        market.deposit(usr2, amountIn, false);

        assertERC20Tracking();

        skip(1 weeks);

        rewardAccumulator.processRewards(address(market), usr1);
        vm.stopPrank();
        vm.startPrank(usr2);

        skip(1 weeks);
        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(gaugeToken, address(market), amountIn, "Gauge transfered from Market");
        verifyReceiveERC20(gaugeToken, usr2, amountIn, "LP received by User 1");

        market.withdraw(amountIn, true);

        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();
    }

    function test_deposit_with_vault_and_repayWithdraw_with_lp_token() external {
        vm.startPrank(usr1);

        gaugeToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(gaugeToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(gaugeToken, address(market), amountIn, "Gauge received by Market");

        market.deposit(usr2, amountIn, true);

        assertERC20Tracking();

        skip(1 weeks);

        market.claimCRV();

        rewardAccumulator.processRewards(address(market), usr1);

        skip(1 weeks);

        vm.stopPrank();
        vm.startPrank(usr2);

        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(gaugeToken, address(market), amountIn, "Gauge transfered from Market");
        verifyBurnERC20(gaugeToken, amountIn, "Gauge Burnt");
        verifyReceiveERC20(collatToken, usr2, amountIn, "LP received by User 1");

        market.withdraw(amountIn, false);

        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();
    }
}

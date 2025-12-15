// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract DepositCurveGaugeMarket is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    CurveGaugeMarket public market;
    IGauge public gaugeToken;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;
    function setUp() public {
        gaugeToken = AddrCurveGauge.PYUSD_USDC;
        collatToken = AddrCurveStableLP.PYUSD_USDC;
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = AddrClassicERC20.PYUSD;
        market = deployCurveGaugeMarket(collatToken, tokens);
        minimumLoan = market.minimumLoan();
    }

    function test_depositBorrow_with_lp_and_repayWithdraw_with_gauge_token() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        gaugeToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(gaugeToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(gaugeToken, address(market), amountIn, "Gauge received by Market");

        market.depositAndBorrow(amountIn, borrowedAmount, true);

        assertERC20Tracking();

        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(gaugeToken, address(market), amountIn, "Gauge transfered from Market");
        verifyBurnERC20(gaugeToken, amountIn, "Gauge Burnt");
        verifyLostERC20(collatToken, address(gaugeToken), amountIn, "LP removed from Curve gauge");
        verifyReceiveERC20(collatToken, usr1, amountIn, "LP received by User 1");

        market.repayAndWithdraw(amountIn, borrowedAmount, false);

        assertERC20Tracking();
    }

    function test_zapDeposit_and_withdraw_with_lp_token() external {
        (, address distributor, , , , ) = gaugeToken.reward_data(address(AddrClassicERC20.PYUSD));

        vm.startPrank(usr1);
        uint256 amountInZap = 100_000 * 10 ** 6;
        uint256 amountOut = 12_000 ether;

        uint256 borrowedAmount = 5_000 ether;

        deal(address(AddrClassicERC20.USDT), usr1, amountInZap);
        deal(address(collatToken), address(zappingProxy), amountOut);

        AddrClassicERC20.USDT.forceApprove(address(market), MAX_UINT);
        market.zapDepositAndBorrow(
            borrowedAmount,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountInZap,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(IERC20.transfer.selector, address(market), amountOut)})
            })
        );
        vm.stopPrank();

        skip(1 weeks);
        vm.startPrank(distributor);
        AddrClassicERC20.PYUSD.approve(address(collatToken), MAX_UINT);
        gaugeToken.deposit_reward_token(address(AddrClassicERC20.PYUSD), 10_000 * 10 ** 6);
        vm.stopPrank();
        assertEq(gaugeToken.balanceOf(address(market)), amountOut);

        vm.startPrank(usr1);

        skip(1 weeks);

        rewardAccumulator.processRewards(address(market), usr1);

        skip(1 weeks);

        rewardAccumulator.claimSimple(address(market));

        market.repayAndWithdraw(amountOut, borrowedAmount, false);
    }
}

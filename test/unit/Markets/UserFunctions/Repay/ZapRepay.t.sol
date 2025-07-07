// TODO remove this comment when the test is ready

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract ZapRepay is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    HDepositConvexCrvLP public hDeposit;

    uint256 initialDeposit = 10_000 ether;
    uint256 initialDebt = 6_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken, true);
        hDeposit = new HDepositConvexCrvLP(usr1, market);

        hDeposit.depositAndBorrow(initialDeposit, initialDebt, true);

        skip(10 days);

        irCalculator.checkpointIR(address(market));
    }

    function test_zap_repay_partial_with_eth() external {
        vm.startPrank(usr2);
        uint256 amountIn = 1 ether;
        uint256 amountOut = 3_000 ether;
        deal(usr2, amountIn);

        deal(address(usg), address(mockRouter), amountOut);

        verifyBurnERC20(usg, amountOut, "usg burnt after zap");

        verifyLostERC20(ETH_NAKED, usr2, amountIn, "Usr2 sends ETH");
        verifyReceiveERC20(ETH_NAKED, address(mockRouter), amountIn, "Router received this ETH");

        market.zapRepay{value: amountIn}(
            usr1,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: 2_999 ether,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, usg, usr2, amountOut)
            })
        );

        assertERC20Tracking();

        assertEq(market.userDebt(usr1), amountOut);
        assertEq(usr2.balance, 0, "Native coin is sent from sender");
        assertEq(address(mockRouter).balance, amountIn, "Native coin sent to router");
    }

    function test_zap_repay_total_with_ERC20_more_than_actualDebt_returns_USG_surplus() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        uint256 amountOut = 10_001 ether;

        deal(address(AddrClassicERC20.USDT), usr1, amountIn);
        deal(address(usg), address(mockRouter), amountOut);

        verifyBurnERC20(usg, initialDebt, "usg burnt after zap");
        verifyReceiveERC20(usg, address(usr1), amountOut - initialDebt, "Usr1 receives the surplus of usg");

        verifyLostERC20(AddrClassicERC20.USDT, usr1, amountIn, "Usr1 sends USDT");
        verifyReceiveERC20(AddrClassicERC20.USDT, address(mockRouter), amountIn, "Router received USDT");

        AddrClassicERC20.USDT.forceApprove(address(market), amountIn);

        market.zapRepay(
            usr1,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, amountIn, usg, usr1, amountOut)
            })
        );

        assertERC20Tracking();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";

contract ZapRepay is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    HDepositConvexCrvLP public hDeposit;

    uint256 initialDeposit = 10_000 ether;
    uint256 initialDebt = 6_000 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);

        hDeposit.depositAndBorrow(usr1, initialDeposit, initialDebt, true);
    }

    function test_zap_repay_partial_with_eth_for_sender() external {
        IERC20 ethNaked = IERC20(address(0));
        uint256 amountIn = 0.1 ether;

        uint256 quote = odosUtils.getQuoteOdos(amountIn, ethNaked, AddrClassicERC20.TOKEN_USDC, usr1);

        vm.mockFunction(address(AddrAggregator.ROUTER_ODOS), address(mockedOdosRouter), abi.encodeWithSelector(IOdosRouter.swapCompact.selector));

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        uint256 nativeCoinBalance = usr1.balance;
        uint256 tgUsdBalance = tgUsd.balanceOf(address(usr1));

        zapper.zapRepay{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ethNaked, amountIn: 0, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IOdosRouter.swapCompact.selector, address(tgUsd), usr1, quote)
        );

        assertEq(tgUsdBalance, tgUsd.balanceOf(address(usr1)), "The repay is not complete, so there are no tgUSD left on the user");
        assertEq(tgUsd.balanceOf(address(zapper)), 0, "No tgUSD should stays on the zapper");
        assertEq(nativeCoinBalance - usr1.balance, amountIn, "Native coin is sent from sender");
        assertEq(market.positionDebt(address(usr1)), initialDebt - quote, "The new debt is equal to the initial minus what has been repayed");
    }

    function test_zap_repay_full_with_eth_for_sender() external {
        IERC20 ethNaked = IERC20(address(0));
        uint256 amountIn = 2 ether;

        uint256 quote = odosUtils.getQuoteOdos(amountIn, ethNaked, AddrClassicERC20.TOKEN_USDC, usr1);

        uint256 tgUsdRemaining = quote - initialDebt;

        vm.mockFunction(address(AddrAggregator.ROUTER_ODOS), address(mockedOdosRouter), abi.encodeWithSelector(IOdosRouter.swapCompact.selector));

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        uint256 nativeCoinBalance = usr1.balance;
        uint256 tgUsdBalance = tgUsd.balanceOf(address(usr1));

        zapper.zapRepay{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ethNaked, amountIn: 0, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IOdosRouter.swapCompact.selector, address(tgUsd), usr1, quote)
        );

        assertEq(tgUsdRemaining, quote - initialDebt, "The repay is complete, all tgUSD in excess from the zap returns to the sender");
        assertEq(tgUsd.balanceOf(address(zapper)), 0, "No tgUSD should stays on the zapper");
        assertEq(nativeCoinBalance - usr1.balance, amountIn, "Native coin is sent from sender");
        assertEq(market.positionDebt(address(usr1)), 0, "Position should be fully repayed");
    }
}

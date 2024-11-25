// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";

contract ZapRepay is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    HDepositConvexCrvLP public hDeposit;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);

        hDeposit.depositAndBorrow(usr1, 10_000 ether, 3_000 ether, true);
    }

    function test_zap_repay_with_eth_for_sender() external {
        IERC20 ethNaked = IERC20(address(0));
        uint256 amountIn = 4 ether;

        uint256 quote = odosUtils.getQuoteOdos(amountIn, ethNaked, AddrClassicERC20.TOKEN_USDC, usr1);
        // bytes memory odosDataCall = getDataForOdosSwapCall(amountIn, ethNaked, 1, tgUsd, address(market));

        vm.mockFunction(address(AddrAggregator.ROUTER_ODOS), address(mockedOdosRouter), abi.encodeWithSelector(IOdosRouter.swapCompact.selector));

        vm.startPrank(usr1);
        deal(usr1, amountIn);
        uint256 before = collatToken.balanceOf(address(market));

        zapper.zapRepay{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ethNaked, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IOdosRouter.swapCompact.selector, address(tgUsd), usr1, quote)
        );
        uint256 collatReceived = collatToken.balanceOf(address(market)) - before;

        // assertApproxEqRel(quote, collatReceived, 1e17, "Collat received by market");

        assertApproxEqRel(quote, market.collateralBalances(usr1), 1e17, "Collat incremented is approx equal to the quote");
    }
}

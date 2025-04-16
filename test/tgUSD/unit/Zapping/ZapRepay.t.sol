// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract ZapRepay is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    HDepositConvexCrvLP public hDeposit;

    uint256 initialDeposit = 10_000 ether;
    uint256 initialDebt = 6_000 ether;

    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);

        hDeposit.depositAndBorrow(initialDeposit, initialDebt, true, usr1);
    }

    function test_zap_repay_partial_with_eth_for_sender() external {
        uint256 amountIn = 0.1 ether;

        (uint256 quote, ) = ensoUtils.getQuote(ETH_NAKED, amountIn, AddrClassicERC20.TOKEN_USDC, 10);
        quote = quote * 10 ** 12;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouter.routeSingle.selector));

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        uint256 nativeCoinBalance = usr1.balance;
        uint256 tgUsdBalance = tgUSD.balanceOf(address(usr1));
        bytes32[] memory commands = Array.memoryBytes32(
            [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(quote)]
        );
        bytes[] memory state = new bytes[](0);

        zapper.zapRepay{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: quote, _for: usr1}),
            abi.encodeWithSelector(IEnsoRouter.routeSingle.selector, address(ETH_NAKED), amountIn, commands, state)
        );

        assertEq(tgUsdBalance, tgUSD.balanceOf(address(usr1)), "The repay is not complete, so there are no tgUSD left on the user");
        assertEq(tgUSD.balanceOf(address(zapper)), 0, "No tgUSD should stays on the zapper");
        assertEq(nativeCoinBalance - usr1.balance, amountIn, "Native coin is sent from sender");
        assertEq(market.userDebt(address(usr1)), initialDebt - quote, "The new debt is equal to the initial minus what has been repayed");
    }

    function test_zap_repay_full_with_erc20_for_sender() external {
        IERC20 tokenIn = AddrClassicERC20.TOKEN_AAVE;
        uint256 amountIn = 30 ether;
        (uint256 quote, ) = ensoUtils.getQuote(tokenIn, amountIn, AddrClassicERC20.TOKEN_FRAX, 10);
        uint256 tgUsdRemaining = quote - initialDebt;
        vm.mockFunction(address(AddrRouter.ENSO_ROUTER), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouter.routeSingle.selector));

        vm.startPrank(usr1);

        deal(address(tokenIn), usr1, amountIn);
        tokenIn.approve(address(zapper), MAX_UINT);
        uint256 erc20Balance = tokenIn.balanceOf(usr1);

        bytes32[] memory commands = Array.memoryBytes32(
            [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(quote)]
        );
        bytes[] memory state = new bytes[](0);

        zapper.zapRepay(
            Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: quote, _for: usr1}),
            abi.encodeWithSelector(IEnsoRouter.routeSingle.selector, address(tokenIn), amountIn, commands, state)
        );

        assertEq(tgUsdRemaining, quote - initialDebt, "The repay is complete, all tgUSD in excess from the zap returns to the sender");
        assertEq(tgUSD.balanceOf(address(zapper)), 0, "No tgUSD should stays on the zapper");
        assertEq(erc20Balance - tokenIn.balanceOf(usr1), amountIn, "Native coin is sent from sender");
        assertEq(market.userDebt(address(usr1)), 0, "Position should be fully repayed");
    }
}

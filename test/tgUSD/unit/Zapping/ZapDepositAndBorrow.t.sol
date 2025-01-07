// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract ZapDepositAndBorrow is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.FRXETH_WETH;

    HZapDepositConvexCrvLP public hZapDeposit;

    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);

        hZapDeposit = new HZapDepositConvexCrvLP(usr1, market, zapper);
    }

    // function test_zap_depositAndBorrow_with_eth_and_stake() external {
    //     uint256 amountIn = 3 ether;
    //     (uint256 quote, uint256 adjustedQuote) = ensoUtils.getQuote(ETH_NAKED, amountIn, collatToken, 10);
    //     uint256 tgUsdToBorrow = 3_000 ether;

    //     vm.startPrank(usr1);
    //     deal(usr1, amountIn * 2);

    //     zapper.zapDepositAndBorrow{value: amountIn}(
    //         Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
    //         ensoUtils.getZapCall(address(zapper), address(market), ETH_NAKED, amountIn, collatToken, adjustedQuote),
    //         tgUsdToBorrow,
    //         true
    //     );

    //     zapper.zapDepositAndBorrow{value: amountIn}(
    //         Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
    //         ensoUtils.getZapCall(address(zapper), address(market), ETH_NAKED, amountIn, collatToken, adjustedQuote),
    //         tgUsdToBorrow,
    //         true
    //     );
    //     vm.stopPrank();

    //     assertEq(market.positionDebt(usr1), tgUsdToBorrow * 2, "The user has borrowed the correct amount of tgUSD");
    //     assertEq(market.positionDebtIndex(usr1), tgUsdToBorrow * 2, "The user has borrowed the correct amount of tgUSD");

    //     assertEq(market.debtIndex(), 1e18, "The debt index of the market is correct");
    //     assertEq(market.totalDebt(), tgUsdToBorrow * 2, "The market has the correct amount of debt");

    //     assertApproxEqRel(market.collateralBalances(usr1), amountIn * 2, 1e16, "The user has deposited the correct amount of collateral");
    //     assertApproxEqRel(market.totalCollateral(), amountIn * 2, 1e16, "The market has the correct amount of collateral");
    // }

    function test_zap_depositAndBorrow_with_erc20_and_stake_no_stake() external {
        uint256 amountIn = 10_000 ether;
        (uint256 quote, uint256 adjustedQuote) = ensoUtils.getQuote(AddrClassicERC20.TOKEN_CRVUSD, amountIn, collatToken, 10);
        uint256 tgUsdToBorrow = 7_000 ether;

        vm.startPrank(usr1);
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr1, amountIn * 2);
        AddrClassicERC20.TOKEN_CRVUSD.approve(address(zapper), MAX_UINT);

        zapper.zapDepositAndBorrow(
            Zapper.ZapMarket({market: address(market), tokenIn: AddrClassicERC20.TOKEN_CRVUSD, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), AddrClassicERC20.TOKEN_CRVUSD, amountIn, collatToken, adjustedQuote),
            tgUsdToBorrow,
            false
        );

        zapper.zapDepositAndBorrow(
            Zapper.ZapMarket({market: address(market), tokenIn: AddrClassicERC20.TOKEN_CRVUSD, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), AddrClassicERC20.TOKEN_CRVUSD, amountIn, collatToken, adjustedQuote),
            tgUsdToBorrow,
            false
        );
        vm.stopPrank();

        assertEq(market.positionDebt(usr1), tgUsdToBorrow * 2, "The user has borrowed the correct amount of tgUSD");
        assertEq(market.positionDebtIndex(usr1), tgUsdToBorrow * 2, "The user has borrowed the correct amount of tgUSD");

        assertEq(market.debtIndex(), 1e18, "The debt index of the market is correct");
        assertEq(market.totalDebt(), tgUsdToBorrow * 2, "The market has the correct amount of debt");

        assertApproxEqRel(market.collateralBalances(usr1), quote * 2, 1e17, "The user has deposited the correct amount of collateral");
        assertApproxEqRel(market.totalCollateral(), quote * 2, 1e17, "The market has the correct amount of collateral");
    }

    // function test_zap_deposit_with_eth_and_no_stake() external {
    //     uint256 amountIn = 3 ether;

    //     uint256 quote = ensoUtils.getQuote(ETH_NAKED, amountIn, collatToken, 10);
    //     hZapDeposit.zapDeposit{value: amountIn}(
    //         Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: quote, _for: usr1}),
    //         ensoUtils.getZapCall(address(zapper), address(market), ETH_NAKED, amountIn, collatToken, quote),
    //         false
    //     );
    // }

    // function test_zap_deposit_with_erc20_and_stake() external {
    //     IERC20 tokenIn = AddrClassicERC20.TOKEN_DOLA;
    //     uint256 amountIn = 10_000 ether;

    //     uint256 quote = ensoUtils.getQuote(tokenIn, amountIn, collatToken, 10);

    //     hZapDeposit.zapDeposit(
    //         Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: quote, _for: usr1}),
    //         ensoUtils.getZapCall(address(zapper), address(market), tokenIn, amountIn, collatToken, quote),
    //         true
    //     );
    // }

    // function test_zap_deposit_with_erc20_and_no_stake() external {
    //     IERC20 tokenIn = AddrClassicERC20.TOKEN_USDT;
    //     uint256 amountIn = 10_000 * 10 ** 6;

    //     uint256 quote = ensoUtils.getQuote(tokenIn, amountIn, collatToken, 10);

    //     hZapDeposit.zapDeposit(
    //         Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: quote, _for: usr1}),
    //         ensoUtils.getZapCall(address(zapper), address(market), tokenIn, amountIn, collatToken, quote),
    //         false
    //     );
    // }
}

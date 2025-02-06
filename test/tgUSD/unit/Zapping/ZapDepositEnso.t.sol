// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract ZapDepositEnso is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.CRVUSD_USDC;

    HZapDepositConvexCrvLP public hZapDeposit;

    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
        hZapDeposit = new HZapDepositConvexCrvLP(usr1, market, zapper);
    }

    function test_zap_deposit_enso_with_eth_and_stake() external {
        uint256 amountIn = 3 ether;
        (, uint256 adjustedQuote) = ensoUtils.getQuote(ETH_NAKED, amountIn, collatToken, 10);

        hZapDeposit.zapDeposit{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), ETH_NAKED, amountIn, collatToken, adjustedQuote),
            true
        );
    }

    function test_zap_deposit_with_eth_and_no_stake() external {
        uint256 amountIn = 3 ether;

        (, uint256 adjustedQuote) = ensoUtils.getQuote(ETH_NAKED, amountIn, collatToken, 10);
        hZapDeposit.zapDeposit{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), ETH_NAKED, amountIn, collatToken, adjustedQuote),
            false
        );
    }

    function test_zap_deposit_with_erc20_and_stake() external {
        IERC20 tokenIn = AddrClassicERC20.TOKEN_DOLA;
        uint256 amountIn = 10_000 ether;

        (, uint256 adjustedQuote) = ensoUtils.getQuote(tokenIn, amountIn, collatToken, 10);

        hZapDeposit.zapDeposit(
            Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), tokenIn, amountIn, collatToken, adjustedQuote),
            true
        );
    }

    function test_zap_deposit_with_erc20_and_no_stake() external {
        IERC20 tokenIn = AddrClassicERC20.TOKEN_USDC;
        uint256 amountIn = 10_000 * 10 ** 6;

        (, uint256 adjustedQuote) = ensoUtils.getQuote(tokenIn, amountIn, collatToken, 10);

        hZapDeposit.zapDeposit(
            Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: adjustedQuote, _for: usr1}),
            ensoUtils.getZapCall(address(zapper), address(market), tokenIn, amountIn, collatToken, adjustedQuote),
            false
        );
    }
}

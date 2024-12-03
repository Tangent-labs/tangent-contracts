// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract ZapDeposit is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.CRVUSD_USDC;

    HZapDepositConvexCrvLP public hZapDeposit;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);

        hZapDeposit = new HZapDepositConvexCrvLP(usr1, market, zapper, odosUtils);
    }

    function test_zap_deposit_with_eth_and_stake() external {
        IERC20 ethNaked = IERC20(address(0));
        uint256 amountIn = 3 ether;

        hZapDeposit.zapDeposit{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ethNaked, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            odosUtils.getDataForOdosSwapCall(amountIn, ethNaked, 1, collatToken, address(market)),
            true
        );
    }

    function test_zap_deposit_with_eth_and_no_stake() external {
        IERC20 ethNaked = IERC20(address(0));
        uint256 amountIn = 3 ether;

        hZapDeposit.zapDeposit{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: ethNaked, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            odosUtils.getDataForOdosSwapCall(amountIn, ethNaked, 1, collatToken, address(market)),
            false
        );
    }

    function test_zap_deposit_with_erc20_and_stake() external {
        IERC20 tokenIn = AddrClassicERC20.TOKEN_DOLA;
        uint256 amountIn = 10_000 ether;

        hZapDeposit.zapDeposit(
            Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            odosUtils.getDataForOdosSwapCall(amountIn, tokenIn, 1, collatToken, address(market)),
            true
        );
    }

    function test_zap_deposit_with_erc20_and_no_stake() external {
        IERC20 tokenIn = AddrClassicERC20.TOKEN_USDT;
        uint256 amountIn = 10_000 * 10 ** 6;

        hZapDeposit.zapDeposit(
            Zapper.ZapMarket({market: address(market), tokenIn: tokenIn, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            odosUtils.getDataForOdosSwapCall(amountIn, tokenIn, 1, collatToken, address(market)),
            false
        );
    }
}

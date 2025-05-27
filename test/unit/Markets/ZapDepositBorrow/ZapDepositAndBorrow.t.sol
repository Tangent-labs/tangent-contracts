// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract ZapDepositAndBorrow is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_zap_depositAndBorrow_with_eth_and_stake() external {
        uint256 tgUsdToBorrow = 533_333 ether;
        uint256 amountIn = 600 ether;
        uint256 amountOut = 550 ether;

        vm.startPrank(usr1);
        deal(usr1, amountIn);
        deal(address(collatToken), address(mockRouter), amountOut);

        market.zapDepositAndBorrow{value: amountIn}(
            tgUsdToBorrow,
            true,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, collatToken, address(market), amountOut)
            })
        );
    }

    function test_zap_depositAndBorrow_with_erc20_and_stake_no_stake() external {
        uint256 tgUsdToBorrow = 533_333 ether;
        uint256 amountIn = 700_000 * 10 ** 6;
        uint256 amountOut = 550 ether;

        vm.startPrank(usr1);
        deal(address(AddrClassicERC20.USDC), usr1, amountIn);
        deal(address(collatToken), address(mockRouter), amountOut);
        AddrClassicERC20.USDC.approve(address(market), MAX_UINT);

        market.zapDepositAndBorrow(
            tgUsdToBorrow,
            false,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDC,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDC, amountIn, collatToken, address(market), amountOut)
            })
        );
    }
}

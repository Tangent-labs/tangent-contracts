// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract LeveragePT is MarketDeploymentContext {
    BasicERC20Market public marketSUSDe;

    IERC20Metadata public collatToken;

    uint256 constant ptAmount = 100_000 ether;

    function setUp() public {
        collatToken = AddrPTPendle.sUSDe_27_11_25;

        marketSUSDe = deployBasicERC20Market(collatToken);

        deal(address(collatToken), address(usr1), ptAmount);

        vm.startPrank(usr1);
        deal(usr1, 10 ether);
        collatToken.approve(address(marketSUSDe), MAX_UINT);
    }

    function test_leverage_PT() external {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(3)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        marketSUSDe.leverage(
            LeverageIn({collatToDeposit: 50_000 ether, usgToFlashMint: 50_000 ether, minCollatAmountOut: 0, isReceiptIn: false}),
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeSwapTokenForPT(
                    encoder.createCurveRouterNoReceiverNoMinDyStruct(
                        Array.memoryAddress(
                            [
                                address(usg),
                                address(lpDeploymentContext.USGLPs("USG-USDC")),
                                address(AddrClassicERC20.USDC),
                                address(AddrCurveStableLP.TRI_USD_POOL),
                                address(AddrClassicERC20.DAI),
                                address(AddrERC4626.sDAI),
                                address(AddrERC4626.sDAI),
                                address(AddrCurveStableLP.sDAI_sUSDe),
                                address(AddrERC4626.sUSDe)
                            ]
                        ),
                        swapParams,
                        50_000 ether
                    ),
                    PendleSYToPT({
                        market: AddrMarketPendle.sUSDe_27_11_25,
                        pt: AddrPTPendle.sUSDe_27_11_25,
                        sy: AddrSYPendle.sUSDe_27_11_25,
                        underlyingIn: address(AddrERC4626.sUSDe),
                        receiver: address(marketSUSDe),
                        minPTOut: 0
                    })
                )
            })
        );

        vm.stopPrank();
    }

    function test_zapDeposit_ETH_to_PT() external {
        uint256[][] memory swapParams = new uint256[][](3);
        swapParams[0] = Array.memoryUint256([uint256(2), uint256(0), uint256(1), uint256(3), uint256(3)]);
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        marketSUSDe.zapDeposit{value: 10 ether}(
            usr1,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: 10 ether,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(pendlePTRouter),
                    routerCall: encoder.encodeSwapTokenForPT(
                        encoder.createCurveRouterNoReceiverNoMinDyStruct(
                            Array.memoryAddress(
                                [
                                    address(ETH_NAKED),
                                    address(AddrCryptoSwapLP.USDT_WBTC_ETH),
                                    address(AddrClassicERC20.USDT),
                                    address(AddrCurveStableLP.USDT_crvUSD),
                                    address(AddrClassicERC20.crvUSD),
                                    address(AddrCurveStableLP.sUSDe_crvUSD),
                                    address(AddrERC4626.sUSDe)
                                ]
                            ),
                            swapParams,
                            10 ether
                        ),
                        PendleSYToPT({
                            market: AddrMarketPendle.sUSDe_27_11_25,
                            pt: AddrPTPendle.sUSDe_27_11_25,
                            sy: AddrSYPendle.sUSDe_27_11_25,
                            underlyingIn: address(AddrERC4626.sUSDe),
                            receiver: address(marketSUSDe),
                            minPTOut: 0
                        })
                    )
                })
            })
        );

        vm.stopPrank();
    }
}

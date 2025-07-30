// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract LeveragePT is MarketDeploymentContext {
    BasicERC20Market public marketSUSDe;

    IERC20Metadata public collatToken;

    uint256 constant ptAmount = 100_000 ether;

    function setUp() public {
        collatToken = AddrPTPendle.sUSDe_31_07_25;

        marketSUSDe = deployBasicERC20Market(collatToken);

        deal(address(collatToken), address(usr1), ptAmount);

        vm.startPrank(usr1);

        collatToken.approve(address(marketSUSDe), MAX_UINT);
    }

    function test_leverage_PT_not_expired() external {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(3)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        marketSUSDe.leverage(
            50_000 ether,
            50_000 ether,
            0,
            ZapStruct({
                router: address(pendleCurveRouter),
                routerCall: encoder.encodeLeverageCallForPendlePT(
                    PendleSYToPT({
                        market: address(AddrMarketPendle.sUSDe_31_07_25),
                        pt: AddrPTPendle.sUSDe_31_07_25,
                        sy: AddrSYPendle.sUSDe_31_07_25,
                        tokenIn: address(AddrERC4626.sUSDe),
                        tokenInAmount: 50_000 ether,
                        receiver: address(marketSUSDe),
                        minPTOut: 0
                    }),
                    encoder.createCurveRouterNoAmountStruct(
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
                        0,
                        address(pendleCurveRouter)
                    )
                )
            })
        );

        vm.stopPrank();
    }

    function test_leverage_PT_expired() external {
        skip(100 days);
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(3)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        marketSUSDe.leverage(
            50_000 ether,
            50_000 ether,
            0,
            ZapStruct({
                router: address(pendleCurveRouter),
                routerCall: encoder.encodeLeverageCallForPendlePT(
                    PendleSYToPT({
                        market: address(AddrMarketPendle.sUSDe_31_07_25),
                        pt: AddrPTPendle.sUSDe_31_07_25,
                        sy: AddrSYPendle.sUSDe_31_07_25,
                        tokenIn: address(AddrERC4626.sUSDe),
                        tokenInAmount: 50_000 ether,
                        receiver: address(marketSUSDe),
                        minPTOut: 0
                    }),
                    encoder.createCurveRouterNoAmountStruct(
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
                        0,
                        address(pendleCurveRouter)
                    )
                )
            })
        );

        vm.stopPrank();
    }
}

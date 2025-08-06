// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract PTLiquidations is MarketDeploymentContext {
    BasicERC20Market public marketSUSDe;

    IERC20Metadata public collatToken;

    uint256 constant ptAmount = 100_000 ether;

    function setUp() public {
        collatToken = AddrPTPendle.sUSDe_31_07_25;

        marketSUSDe = deployBasicERC20Market(collatToken);

        deal(address(collatToken), address(usr1), ptAmount);

        vm.startPrank(usr1);

        collatToken.approve(address(marketSUSDe), MAX_UINT);
        marketSUSDe.depositAndBorrow(ptAmount, 50_000 ether);
    }

    function test_liquidate_PT_not_expired() external {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(3)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);

        marketSUSDe.selfLiquidate(
            50_000 ether,
            20_000 ether,
            0,
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeLiquidateCallForPendlePT(
                    PendlePTToSY({
                        market: AddrMarketPendle.sUSDe_31_07_25,
                        pt: AddrPTPendle.sUSDe_31_07_25,
                        sy: AddrSYPendle.sUSDe_31_07_25,
                        yt: AddrYTPendle.sUSDe_31_07_25,
                        underlyingOut: address(AddrERC4626.sUSDe),
                        ptAmount: 50_000 ether
                    }),
                    encoder.createCurveRouterNoAmountStruct(
                        Array.memoryAddress(
                            [
                                address(AddrERC4626.sUSDe),
                                address(AddrCurveStableLP.sDAI_sUSDe),
                                address(AddrERC4626.sDAI),
                                address(AddrERC4626.sDAI),
                                address(AddrClassicERC20.DAI),
                                address(AddrCurveStableLP.TRI_USD_POOL),
                                address(AddrClassicERC20.USDC),
                                address(lpDeploymentContext.USGLPs("USG-USDC")),
                                address(usg)
                            ]
                        ),
                        swapParams,
                        0,
                        usr1
                    )
                )
            })
        );

        vm.stopPrank();
    }

    function test_liquidate_PT_expired() external {
        skip(100 days);
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(3)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);

        marketSUSDe.selfLiquidate(
            50_000 ether,
            20_000 ether,
            0,
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeLiquidateCallForPendlePT(
                    PendlePTToSY({
                        market: AddrMarketPendle.sUSDe_31_07_25,
                        pt: AddrPTPendle.sUSDe_31_07_25,
                        sy: AddrSYPendle.sUSDe_31_07_25,
                        yt: AddrYTPendle.sUSDe_31_07_25,
                        underlyingOut: address(AddrERC4626.sUSDe),
                        ptAmount: 50_000 ether
                    }),
                    encoder.createCurveRouterNoAmountStruct(
                        Array.memoryAddress(
                            [
                                address(AddrERC4626.sUSDe),
                                address(AddrCurveStableLP.sDAI_sUSDe),
                                address(AddrERC4626.sDAI),
                                address(AddrERC4626.sDAI),
                                address(AddrClassicERC20.DAI),
                                address(AddrCurveStableLP.TRI_USD_POOL),
                                address(AddrClassicERC20.USDC),
                                address(lpDeploymentContext.USGLPs("USG-USDC")),
                                address(usg)
                            ]
                        ),
                        swapParams,
                        0,
                        usr1
                    )
                )
            })
        );

        vm.stopPrank();
    }
}

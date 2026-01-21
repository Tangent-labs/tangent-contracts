// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract PTLiquidations is MarketDeploymentContext {
    BasicERC20Market public marketSUSDe;
    BasicERC20Market public marketwstUSR;

    IERC20Metadata public sUSDe = AddrPTPendle.sUSDe_31_07_25;
    IERC20Metadata public wstUSR = AddrPTPendle.wstUSR_29_01_26;
    uint256 constant ptAmount = 100_000 ether;

    function setUp() public {
        marketSUSDe = deployBasicERC20Market(sUSDe);
        marketwstUSR = deployBasicERC20Market(wstUSR);

        deal(address(sUSDe), address(usr1), ptAmount);
        deal(address(wstUSR), address(usr1), ptAmount);

        vm.startPrank(usr1);

        sUSDe.approve(address(marketSUSDe), MAX_UINT);
        wstUSR.approve(address(marketwstUSR), MAX_UINT);

        marketSUSDe.depositAndBorrow(ptAmount, 50_000 ether, false);
        marketwstUSR.depositAndBorrow(ptAmount, 50_000 ether, false);
    }

    function test_liquidate_PT_not_expired_2() external {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);
        swapParams[2] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);
        marketwstUSR.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: 50_000 ether, usgToRepay: 20_000 ether, maxUsgToBurn: MAX_UINT, minUsgOut: 0, isReceiptOut: false}),
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeSwapPTForToken(
                    PendlePTToSY({
                        market: AddrMarketPendle.wstUSR_29_01_26,
                        pt: AddrPTPendle.wstUSR_29_01_26,
                        sy: AddrSYPendle.wstUSR_29_01_26,
                        yt: AddrYTPendle.wstUSR_29_01_26,
                        underlyingOut: address(AddrERC4626.wstUSR),
                        ptAmount: 50_000 ether
                    }),
                    encoder.createCurveRouterNoAmountStruct(
                        Array.memoryAddress(
                            [
                                address(AddrERC4626.wstUSR),
                                address(0x64273624eb57c5cA961d366CBF3968e760Bf0452),
                                address(0x865377367054516e17014CcdED1e7d814EDC9ce4),
                                address(0x8b83c4aA949254895507D09365229BC3a8c7f710),
                                address(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                                address(0x81A2612F6dEA269a6Dd1F6DeAb45C5424EE2c4b7),
                                address(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29),
                                address(lpDeploymentContext.USGLPs("USG-frxUSD")),
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

    function test_liquidate_PT_not_expired() external {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(3)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);
        marketSUSDe.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: 50_000 ether, usgToRepay: 20_000 ether, maxUsgToBurn: MAX_UINT, minUsgOut: 0, isReceiptOut: false}),
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeSwapPTForToken(
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
                        10 ether,
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
            SelfLiquidateIn({collatAmountToLiquidate: 50_000 ether, usgToRepay: 20_000 ether, maxUsgToBurn: MAX_UINT, minUsgOut: 0, isReceiptOut: false}),
            ZapStruct({
                router: address(pendlePTRouter),
                routerCall: encoder.encodeSwapPTForToken(
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
                        10 ether,
                        usr1
                    )
                )
            })
        );

        vm.stopPrank();
    }
}

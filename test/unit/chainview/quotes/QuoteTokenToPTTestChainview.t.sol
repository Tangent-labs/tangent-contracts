// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../contexts/MarketDeploymentContext.sol";
import {QuotePTToToken, QuotePTToTokenParams, PendlePTToSYQuote, QuotePtToTokenOut} from "../../../../src/chainview/USG/bot/QuotePTToToken.cv.sol";
import {QuoteTokenToPT, QuoteTokenToPTParams, PendleSYToPTQuote, QuoteTokenToPTOut} from "../../../../src/chainview/USG/bot/QuoteTokenToPT.cv.sol";
import {CurveQuote, CurveRouteParamsOnly} from "../../../../src/interfaces/internals/USG/ICurveLPLiquidator.sol";

contract QuoteTokenToPTTestChainview is MarketDeploymentContext {
    function setUp() public {
        deal(address(AddrPTPendle.sUSDe_25_09_25), address(usr1), 50_000 ether);
        deal(address(AddrPTPendle.wstUSR_25_09_25), address(usr1), 50_000 ether);
        deal(address(AddrPTPendle.USDe_25_09_25), address(usr1), 50_000 ether);
        deal(address(AddrPTPendle.USR_04_09_25), address(usr1), 50_000 ether);
        deal(address(AddrClassicERC20.USDC), address(usr1), 50_000 * 1e6);

        vm.startPrank(usr1);

        AddrPTPendle.USDe_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
        AddrPTPendle.sUSDe_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
        AddrPTPendle.wstUSR_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
        AddrPTPendle.USR_04_09_25.approve(address(pendlePTRouter), MAX_UINT);
        AddrClassicERC20.USDC.approve(address(pendlePTRouter), MAX_UINT);
    }

    function test_quote_pendle_PT_to_USDC_with_sUSDe() public {
        // IN
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        QuotePTToTokenParams[] memory quoteInParams = new QuotePTToTokenParams[](1);
        CurveQuote memory routerQuoteIn = encoder.createCurveQuoteStruct(
            Array.memoryAddress(
                [
                    address(AddrERC4626.sUSDe),
                    address(AddrCurveStableLP.scrvUSD_sUSDe),
                    address(AddrERC4626.scrvUSD),
                    address(AddrERC4626.scrvUSD),
                    address(AddrClassicERC20.crvUSD),
                    address(AddrCurveStableLP.USDC_crvUSD),
                    address(AddrClassicERC20.USDC),
                    address(lpDeploymentContext.USGLPs("USG-USDC")),
                    address(usg)
                ]
            ),
            swapParams,
            0
        );

        CurveRouteParamsOnly memory routerDataIn = CurveRouteParamsOnly({_route: routerQuoteIn._route, _swap_params: routerQuoteIn._swap_params, _pools: routerQuoteIn._pools});

        quoteInParams[0] = QuotePTToTokenParams({
            ptToSYData: PendlePTToSYQuote({
                market: AddrMarketPendle.sUSDe_05_02_26,
                pt: AddrPTPendle.sUSDe_05_02_26,
                sy: AddrSYPendle.sUSDe_05_02_26,
                underlyingOut: address(AddrERC4626.sUSDe),
                ptAmount: 1 ether
            }),
            curveRouterData: routerDataIn
        });

        try new QuotePTToToken(quoteInParams) {} catch (bytes memory reason) {
            QuotePtToTokenOut[] memory quotes = abi.decode(removeFirst4Bytes(reason), (QuotePtToTokenOut[]));
            console.log(quotes[0].quote);
            console.log(quotes[0].priceImpact);
            assertApproxEqRel(oracles[AddrPTPendle.sUSDe_05_02_26].latestAnswer(true), quotes[0].quote, 5e15);
        }

        // uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
        //     PendlePTToSY({
        //         market: AddrMarketPendle.sUSDe_05_02_26,
        //         pt: AddrPTPendle.sUSDe_05_02_26,
        //         sy: AddrSYPendle.sUSDe_05_02_26,
        //         yt: AddrYTPendle.sUSDe_05_02_26,
        //         underlyingOut: address(AddrERC4626.sUSDe),
        //         ptAmount: 1 ether
        //     }),
        //     CurveRouterSwapNoAmount({_route: routerDataIn._route, _swap_params: routerDataIn._swap_params, _min_dy: 0, _pools: routerDataIn._pools, _receiver: usr1})
        // );

        // try new QuotePTToToken(quoteInParams) {} catch (bytes memory reason) {
        //     uint256[] memory quotes = abi.decode(removeFirst4Bytes(reason), (uint256[]));
        //     assertApproxEqRel(realUSDCReturned, quotes[0], 5e15);
        //     assertApproxEqRel(oracles[AddrPTPendle.sUSDe_05_02_26].latestAnswer(true), quotes[0] * 1e12, 5e15);
        // }
    }

    function test_quote_pendle_PT_to_USDC_price_impact() public {
        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

        QuotePTToTokenParams[] memory quoteInParams = new QuotePTToTokenParams[](1);
        CurveQuote memory routerQuoteIn = encoder.createCurveQuoteStruct(
            Array.memoryAddress(
                [
                    address(AddrERC4626.sUSDe),
                    address(AddrCurveStableLP.scrvUSD_sUSDe),
                    address(AddrERC4626.scrvUSD),
                    address(AddrERC4626.scrvUSD),
                    address(AddrClassicERC20.crvUSD),
                    address(AddrCurveStableLP.USDC_crvUSD),
                    address(AddrClassicERC20.USDC),
                    address(lpDeploymentContext.USGLPs("USG-USDC")),
                    address(usg)
                ]
            ),
            swapParams,
            0
        );

        CurveRouteParamsOnly memory routerDataIn = CurveRouteParamsOnly({_route: routerQuoteIn._route, _swap_params: routerQuoteIn._swap_params, _pools: routerQuoteIn._pools});

        // Use a larger amount to generate measurable price impact
        quoteInParams[0] = QuotePTToTokenParams({
            ptToSYData: PendlePTToSYQuote({
                market: AddrMarketPendle.sUSDe_05_02_26,
                pt: AddrPTPendle.sUSDe_05_02_26,
                sy: AddrSYPendle.sUSDe_05_02_26,
                underlyingOut: address(AddrERC4626.sUSDe),
                ptAmount: 1000 ether
            }),
            curveRouterData: routerDataIn
        });

        try new QuotePTToToken(quoteInParams) {} catch (bytes memory reason) {
            QuotePtToTokenOut[] memory quotes = abi.decode(removeFirst4Bytes(reason), (QuotePtToTokenOut[]));
            assertGt(quotes[0].quote, 0, "Quote should be > 0");
            assertGe(quotes[0].priceImpact, 0, "Price impact should be >= 0 on stable pools");
        }
    }

    function test_quote_USDC_to_pendle_PT_price_impact() public {
        // Route: USDC → crvUSD → scrvUSD (wrap) → sUSDe
        uint256[][] memory swapParams = new uint256[][](3);
        swapParams[0] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);  // USDC → crvUSD
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);  // crvUSD → scrvUSD (wrap)
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]); // scrvUSD → sUSDe

        CurveQuote memory curveQuote = encoder.createCurveQuoteStruct(
            Array.memoryAddress(
                [
                    address(AddrClassicERC20.USDC),
                    address(AddrCurveStableLP.USDC_crvUSD),
                    address(AddrClassicERC20.crvUSD),
                    address(AddrERC4626.scrvUSD),
                    address(AddrERC4626.scrvUSD),
                    address(AddrCurveStableLP.scrvUSD_sUSDe),
                    address(AddrERC4626.sUSDe)
                ]
            ),
            swapParams,
            1000 * 1e6
        );

        QuoteTokenToPTParams[] memory params = new QuoteTokenToPTParams[](1);
        params[0] = QuoteTokenToPTParams({
            curveRouterData: curveQuote,
            syToPTData: PendleSYToPTQuote({
                market: AddrMarketPendle.sUSDe_05_02_26,
                pt: AddrPTPendle.sUSDe_05_02_26,
                sy: AddrSYPendle.sUSDe_05_02_26,
                underlyingIn: address(AddrERC4626.sUSDe),
                tokenInAmount: 1000 * 1e6
            })
        });

        try new QuoteTokenToPT(params) {} catch (bytes memory reason) {
            QuoteTokenToPTOut[] memory quotes = abi.decode(removeFirst4Bytes(reason), (QuoteTokenToPTOut[]));
            assertGt(quotes[0].quote, 0, "Quote should be > 0");
            assertGe(quotes[0].priceImpact, 0, "Price impact should be >= 0 on stable pools");
        }
    }

    // function test_quote_pendle_USDC_to_PT_with_USDe() public {
    //     // IN
    //     uint256[][] memory swapParams = new uint256[][](1);
    //     swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);

    //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
    //         Array.memoryAddress([address(AddrClassicERC20.USDC), address(AddrCurveStableLP.USDe_USDC), address(AddrClassicERC20.USDe)]),
    //         swapParams,
    //         0,
    //         address(pendlePTRouter)
    //     );

    //     PendlePTOutQuoteParams[] memory quoteOutParams = new PendlePTOutQuoteParams[](1);

    //     quoteOutParams[0] = PendlePTOutQuoteParams({
    //         syToPTData: PendleSYToPTQuote({
    //             market: AddrMarketPendle.USDe_25_09_25,
    //             pt: AddrPTPendle.USDe_25_09_25,
    //             sy: AddrSYPendle.USDe_25_09_25,
    //             underlyingIn: address(AddrClassicERC20.USDe),
    //             tokenInAmount: 1e6
    //         }),
    //         curveRouterData: routerData
    //     });

    //     uint256 realPTReturned = pendlePTRouter.swapTokenForPT(
    //         PendleSYToPT({
    //             market: AddrMarketPendle.USDe_25_09_25,
    //             pt: AddrPTPendle.USDe_25_09_25,
    //             sy: AddrSYPendle.USDe_25_09_25,
    //             underlyingIn: address(AddrClassicERC20.USDe),
    //             receiver: usr1,
    //             tokenInAmount: 1e6,
    //             minPTOut: 0
    //         }),
    //         routerData
    //     );

    //     try new QuotesPendlePT(new PendlePTInQuoteParams[](0), quoteOutParams) {} catch (bytes memory reason) {
    //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
    //         assertApproxEqRel(realPTReturned, quotesOut[0], 5e15);
    //         assertApproxEqRel(10 ** 36 / oracles[AddrPTPendle.sUSDe_25_09_25].latestAnswer(true), quotesOut[0], 5e15);
    //     }
    // }

    // function test_quote_pendle_PT_with_USDe() public {
    //     uint256[][] memory swapParams = new uint256[][](1);
    //     swapParams[0] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

    //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

    //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
    //         Array.memoryAddress([address(AddrClassicERC20.USDe), address(AddrCurveStableLP.USDe_USDC), address(AddrClassicERC20.USDC)]),
    //         swapParams,
    //         0,
    //         usr1
    //     );

    //     quoteInParams[0] = PendlePTInQuoteParams({
    //         ptToSYData: PendlePTToSYQuote({
    //             market: AddrMarketPendle.USDe_25_09_25,
    //             pt: AddrPTPendle.USDe_25_09_25,
    //             sy: AddrSYPendle.USDe_25_09_25,
    //             underlyingOut: address(AddrClassicERC20.USDe),
    //             ptAmount: 1 ether
    //         }),
    //         curveRouterData: routerData
    //     });

    //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
    //         PendlePTToSY({
    //             market: AddrMarketPendle.USDe_25_09_25,
    //             pt: AddrPTPendle.USDe_25_09_25,
    //             sy: AddrSYPendle.USDe_25_09_25,
    //             yt: AddrYTPendle.USDe_25_09_25,
    //             underlyingOut: address(AddrClassicERC20.USDe),
    //             ptAmount: 1 ether
    //         }),
    //         routerData
    //     );

    //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
    //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
    //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
    //         assertApproxEqRel(oracles[AddrPTPendle.USDe_25_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
    //     }
    // }

    // function test_quote_pendle_PT_with_wstUSR() public {
    //     uint256[][] memory swapParams = new uint256[][](2);
    //     swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
    //     swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

    //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

    //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
    //         Array.memoryAddress(
    //             [address(AddrERC4626.wstUSR), address(AddrERC4626.wstUSR), address(AddrClassicERC20.USR), address(AddrCurveStableLP.USR_USDC), address(AddrClassicERC20.USDC)]
    //         ),
    //         swapParams,
    //         0,
    //         usr1
    //     );

    //     quoteInParams[0] = PendlePTInQuoteParams({
    //         ptToSYData: PendlePTToSYQuote({
    //             market: AddrMarketPendle.wstUSR_25_09_25,
    //             pt: AddrPTPendle.wstUSR_25_09_25,
    //             sy: AddrSYPendle.wstUSR_25_09_25,
    //             underlyingOut: address(AddrERC4626.wstUSR),
    //             ptAmount: 1 ether
    //         }),
    //         curveRouterData: routerData
    //     });

    //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
    //         PendlePTToSY({
    //             market: AddrMarketPendle.wstUSR_25_09_25,
    //             pt: AddrPTPendle.wstUSR_25_09_25,
    //             sy: AddrSYPendle.wstUSR_25_09_25,
    //             yt: AddrYTPendle.wstUSR_25_09_25,
    //             underlyingOut: address(AddrERC4626.wstUSR),
    //             ptAmount: 1 ether
    //         }),
    //         routerData
    //     );

    //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
    //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
    //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
    //         assertApproxEqRel(oracles[AddrPTPendle.wstUSR_25_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
    //     }
    // }
    // function test_quote_pendle_PT_with_USR() public {
    //     uint256[][] memory swapParams = new uint256[][](1);
    //     swapParams[0] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

    //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

    //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
    //         Array.memoryAddress([address(AddrClassicERC20.USR), address(AddrCurveStableLP.USR_USDC), address(AddrClassicERC20.USDC)]),
    //         swapParams,
    //         0,
    //         usr1
    //     );

    //     quoteInParams[0] = PendlePTInQuoteParams({
    //         ptToSYData: PendlePTToSYQuote({
    //             market: AddrMarketPendle.USR_04_09_25,
    //             pt: AddrPTPendle.USR_04_09_25,
    //             sy: AddrSYPendle.USR_04_09_25,
    //             underlyingOut: address(AddrClassicERC20.USR),
    //             ptAmount: 1 ether
    //         }),
    //         curveRouterData: routerData
    //     });

    //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
    //         PendlePTToSY({
    //             market: AddrMarketPendle.USR_04_09_25,
    //             pt: AddrPTPendle.USR_04_09_25,
    //             sy: AddrSYPendle.USR_04_09_25,
    //             yt: AddrYTPendle.USR_04_09_25,
    //             underlyingOut: address(AddrClassicERC20.USR),
    //             ptAmount: 1 ether
    //         }),
    //         routerData
    //     );

    //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
    //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));

    //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
    //         assertApproxEqRel(oracles[AddrPTPendle.USR_04_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
    //     }
    // }
}

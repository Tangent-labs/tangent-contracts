// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "../../../contexts/MarketDeploymentContext.sol";
// import {QuotePTToToken, QuotePTToTokenParams, PendlePTToSYQuote} from "../../../../src/chainview/USG/bot/QuotePTToToken.cv.sol";

// contract QuoteTokenToPTTestChainview is MarketDeploymentContext {
//     function setUp() public {
//         deal(address(AddrPTPendle.sUSDe_25_09_25), address(usr1), 50_000 ether);
//         deal(address(AddrPTPendle.wstUSR_25_09_25), address(usr1), 50_000 ether);
//         deal(address(AddrPTPendle.USDe_25_09_25), address(usr1), 50_000 ether);
//         deal(address(AddrPTPendle.USR_04_09_25), address(usr1), 50_000 ether);
//         deal(address(AddrClassicERC20.USDC), address(usr1), 50_000 * 1e6);

//         vm.startPrank(usr1);

//         AddrPTPendle.USDe_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
//         AddrPTPendle.sUSDe_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
//         AddrPTPendle.wstUSR_25_09_25.approve(address(pendlePTRouter), MAX_UINT);
//         AddrPTPendle.USR_04_09_25.approve(address(pendlePTRouter), MAX_UINT);
//         AddrClassicERC20.USDC.approve(address(pendlePTRouter), MAX_UINT);
//     }
//     function test_quote_pendle_PT_to_USDC_with_sUSDe() public {
//         // IN
//         uint256[][] memory swapParams = new uint256[][](4);
//         swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);
//         swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
//         swapParams[2] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(3)]);
//         swapParams[3] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);

//         QuotePTToTokenParams[] memory quoteInParams = new QuotePTToTokenParams[](1);
//         CurveQuote memory routerDataIn = encoder.createCurveQuoteStruct(
//             Array.memoryAddress(
//                 [
//                     address(AddrERC4626.sUSDe),
//                     address(AddrCurveStableLP.sDAI_sUSDe),
//                     address(AddrERC4626.sDAI),
//                     address(AddrERC4626.sDAI),
//                     address(AddrClassicERC20.DAI),
//                     address(AddrCurveStableLP.TRI_USD_POOL),
//                     address(AddrClassicERC20.USDC)
//                 ]
//             ),
//             swapParams,
//             0
//         );

//         quoteInParams[0] = QuotePTToTokenParams({
//             ptToSYData: PendlePTToSYQuote({
//                 market: AddrMarketPendle.sUSDe_25_09_25,
//                 pt: AddrPTPendle.sUSDe_25_09_25,
//                 sy: AddrSYPendle.sUSDe_25_09_25,
//                 underlyingOut: address(AddrERC4626.sUSDe),
//                 ptAmount: 1 ether
//             }),
//             curveRouterData: routerDataIn
//         });

//         uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
//             PendlePTToSY({
//                 market: AddrMarketPendle.sUSDe_25_09_25,
//                 pt: AddrPTPendle.sUSDe_25_09_25,
//                 sy: AddrSYPendle.sUSDe_25_09_25,
//                 yt: AddrYTPendle.sUSDe_25_09_25,
//                 underlyingOut: address(AddrERC4626.sUSDe),
//                 ptAmount: 1 ether
//             }),
//             CurveRouterSwapNoAmount({_route: routerDataIn._route, _swap_params: routerDataIn._swap_params, _min_dy: 0, _pools: routerDataIn._pools, _receiver: usr1})
//         );

//         try new QuotePTToToken(quoteInParams) {} catch (bytes memory reason) {
//             uint256[] memory quotes = abi.decode(removeFirst4Bytes(reason), (uint256[]));
//             assertApproxEqRel(realUSDCReturned, quotes[0], 5e15);
//             assertApproxEqRel(oracles[AddrPTPendle.sUSDe_25_09_25].latestAnswer(true), quotes[0] * 1e12, 5e15);
//         }
//     }

//     // function test_quote_pendle_USDC_to_PT_with_USDe() public {
//     //     // IN
//     //     uint256[][] memory swapParams = new uint256[][](1);
//     //     swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(10), uint256(2)]);

//     //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
//     //         Array.memoryAddress([address(AddrClassicERC20.USDC), address(AddrCurveStableLP.USDe_USDC), address(AddrClassicERC20.USDe)]),
//     //         swapParams,
//     //         0,
//     //         address(pendlePTRouter)
//     //     );

//     //     PendlePTOutQuoteParams[] memory quoteOutParams = new PendlePTOutQuoteParams[](1);

//     //     quoteOutParams[0] = PendlePTOutQuoteParams({
//     //         syToPTData: PendleSYToPTQuote({
//     //             market: AddrMarketPendle.USDe_25_09_25,
//     //             pt: AddrPTPendle.USDe_25_09_25,
//     //             sy: AddrSYPendle.USDe_25_09_25,
//     //             underlyingIn: address(AddrClassicERC20.USDe),
//     //             tokenInAmount: 1e6
//     //         }),
//     //         curveRouterData: routerData
//     //     });

//     //     uint256 realPTReturned = pendlePTRouter.swapTokenForPT(
//     //         PendleSYToPT({
//     //             market: AddrMarketPendle.USDe_25_09_25,
//     //             pt: AddrPTPendle.USDe_25_09_25,
//     //             sy: AddrSYPendle.USDe_25_09_25,
//     //             underlyingIn: address(AddrClassicERC20.USDe),
//     //             receiver: usr1,
//     //             tokenInAmount: 1e6,
//     //             minPTOut: 0
//     //         }),
//     //         routerData
//     //     );

//     //     try new QuotesPendlePT(new PendlePTInQuoteParams[](0), quoteOutParams) {} catch (bytes memory reason) {
//     //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
//     //         assertApproxEqRel(realPTReturned, quotesOut[0], 5e15);
//     //         assertApproxEqRel(10 ** 36 / oracles[AddrPTPendle.sUSDe_25_09_25].latestAnswer(true), quotesOut[0], 5e15);
//     //     }
//     // }

//     // function test_quote_pendle_PT_with_USDe() public {
//     //     uint256[][] memory swapParams = new uint256[][](1);
//     //     swapParams[0] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

//     //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

//     //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
//     //         Array.memoryAddress([address(AddrClassicERC20.USDe), address(AddrCurveStableLP.USDe_USDC), address(AddrClassicERC20.USDC)]),
//     //         swapParams,
//     //         0,
//     //         usr1
//     //     );

//     //     quoteInParams[0] = PendlePTInQuoteParams({
//     //         ptToSYData: PendlePTToSYQuote({
//     //             market: AddrMarketPendle.USDe_25_09_25,
//     //             pt: AddrPTPendle.USDe_25_09_25,
//     //             sy: AddrSYPendle.USDe_25_09_25,
//     //             underlyingOut: address(AddrClassicERC20.USDe),
//     //             ptAmount: 1 ether
//     //         }),
//     //         curveRouterData: routerData
//     //     });

//     //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
//     //         PendlePTToSY({
//     //             market: AddrMarketPendle.USDe_25_09_25,
//     //             pt: AddrPTPendle.USDe_25_09_25,
//     //             sy: AddrSYPendle.USDe_25_09_25,
//     //             yt: AddrYTPendle.USDe_25_09_25,
//     //             underlyingOut: address(AddrClassicERC20.USDe),
//     //             ptAmount: 1 ether
//     //         }),
//     //         routerData
//     //     );

//     //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
//     //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
//     //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
//     //         assertApproxEqRel(oracles[AddrPTPendle.USDe_25_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
//     //     }
//     // }

//     // function test_quote_pendle_PT_with_wstUSR() public {
//     //     uint256[][] memory swapParams = new uint256[][](2);
//     //     swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(9), uint256(0), uint256(0)]);
//     //     swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

//     //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

//     //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
//     //         Array.memoryAddress(
//     //             [address(AddrERC4626.wstUSR), address(AddrERC4626.wstUSR), address(AddrClassicERC20.USR), address(AddrCurveStableLP.USR_USDC), address(AddrClassicERC20.USDC)]
//     //         ),
//     //         swapParams,
//     //         0,
//     //         usr1
//     //     );

//     //     quoteInParams[0] = PendlePTInQuoteParams({
//     //         ptToSYData: PendlePTToSYQuote({
//     //             market: AddrMarketPendle.wstUSR_25_09_25,
//     //             pt: AddrPTPendle.wstUSR_25_09_25,
//     //             sy: AddrSYPendle.wstUSR_25_09_25,
//     //             underlyingOut: address(AddrERC4626.wstUSR),
//     //             ptAmount: 1 ether
//     //         }),
//     //         curveRouterData: routerData
//     //     });

//     //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
//     //         PendlePTToSY({
//     //             market: AddrMarketPendle.wstUSR_25_09_25,
//     //             pt: AddrPTPendle.wstUSR_25_09_25,
//     //             sy: AddrSYPendle.wstUSR_25_09_25,
//     //             yt: AddrYTPendle.wstUSR_25_09_25,
//     //             underlyingOut: address(AddrERC4626.wstUSR),
//     //             ptAmount: 1 ether
//     //         }),
//     //         routerData
//     //     );

//     //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
//     //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));
//     //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
//     //         assertApproxEqRel(oracles[AddrPTPendle.wstUSR_25_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
//     //     }
//     // }
//     // function test_quote_pendle_PT_with_USR() public {
//     //     uint256[][] memory swapParams = new uint256[][](1);
//     //     swapParams[0] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]);

//     //     PendlePTInQuoteParams[] memory quoteInParams = new PendlePTInQuoteParams[](1);

//     //     CurveRouterSwapNoAmount memory routerData = encoder.createCurveRouterNoAmountStruct(
//     //         Array.memoryAddress([address(AddrClassicERC20.USR), address(AddrCurveStableLP.USR_USDC), address(AddrClassicERC20.USDC)]),
//     //         swapParams,
//     //         0,
//     //         usr1
//     //     );

//     //     quoteInParams[0] = PendlePTInQuoteParams({
//     //         ptToSYData: PendlePTToSYQuote({
//     //             market: AddrMarketPendle.USR_04_09_25,
//     //             pt: AddrPTPendle.USR_04_09_25,
//     //             sy: AddrSYPendle.USR_04_09_25,
//     //             underlyingOut: address(AddrClassicERC20.USR),
//     //             ptAmount: 1 ether
//     //         }),
//     //         curveRouterData: routerData
//     //     });

//     //     uint256 realUSDCReturned = pendlePTRouter.swapPTForToken(
//     //         PendlePTToSY({
//     //             market: AddrMarketPendle.USR_04_09_25,
//     //             pt: AddrPTPendle.USR_04_09_25,
//     //             sy: AddrSYPendle.USR_04_09_25,
//     //             yt: AddrYTPendle.USR_04_09_25,
//     //             underlyingOut: address(AddrClassicERC20.USR),
//     //             ptAmount: 1 ether
//     //         }),
//     //         routerData
//     //     );

//     //     try new QuotesPendlePT(quoteInParams, new PendlePTOutQuoteParams[](0)) {} catch (bytes memory reason) {
//     //         (uint256[] memory quotesIn, uint256[] memory quotesOut) = abi.decode(removeFirst4Bytes(reason), (uint256[], uint256[]));

//     //         assertApproxEqRel(realUSDCReturned, quotesIn[0], 5e15);
//     //         assertApproxEqRel(oracles[AddrPTPendle.USR_04_09_25].latestAnswer(true), quotesIn[0] * 1e12, 5e15);
//     //     }
//     // }
// }

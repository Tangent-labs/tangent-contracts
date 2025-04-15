// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import {QuoteLiquidationRouter, CurveQuote} from "../../../src/chainview/tgUSD/bot/QuoteLiquidationRouter.cv.sol";

contract QuoteLiquidationRouterChainview is ConvexCurveContext {
    uint256 constant ZERO = 0;

    function test_quote_curve_router_chainview_without_wStable_fxUSD() public {
        CurveQuote[] memory quoteIn = new CurveQuote[](1);
        address[11] memory route = [
            address(AddrCurveStableLP.USDC_FXUSD),
            address(AddrCurveStableLP.USDC_FXUSD),
            address(AddrClassicERC20.TOKEN_USDC),
            address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
            address(tgUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
            [ZERO, uint256(1), uint256(1), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        console.log(curveQuote._amount);

        

        quoteIn[0] =curveQuote;

        try new QuoteLiquidationRouter(quoteIn) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    // QUOTE crvUSD-USDC => USDC => tgUSD-USDC => tgUSD
    function test_quote_curve_router_chainview_without_wStable() public {
        CurveQuote[] memory curveQuotes = new CurveQuote[](2);
        address[11] memory route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_USDC),
            address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
            address(tgUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
            [ZERO, uint256(1), uint256(1), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        curveQuotes[0] = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        curveQuotes[1] = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        try new QuoteLiquidationRouter(curveQuotes) {} catch (bytes memory reason) {
            // parse revert reason
            uint256[] memory results = abi.decode(removeFirst4Bytes(reason), (uint256[]));            assertGt(results[0], 100 ether);
            console.log(results[0]);
             console.log(results[1]);

            assertTrue(reason.length > 3, "Chainview failed");
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    // QUOTE crvUSD-USDC => crvUSD => wcrvUSD => tgUSD-wcrvUSD => tgUSD
    function test_liquidator_curve_router_chainview_with_wStable() public {
        CurveQuote[] memory curveQuotes = new CurveQuote[](2);

        address[11] memory route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_CRVUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, uint256(1), uint256(6), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        curveQuotes[0] = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        curveQuotes[1] = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});
        try new QuoteLiquidationRouter(curveQuotes) {} catch (bytes memory reason) {
            // parse revert reason
            uint256[] memory results = abi.decode(removeFirst4Bytes(reason), (uint256[]));
            assertGt(results[0], 100 ether);
            console.log(results[0]);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    // function getFxsROute() internal pure returns (address[11] memory route, uint256[5][5] memory swapParams) {
    //     route = [
    //         address(AddrCurveStableLP.USDC_FXUSD),
    //         address(AddrCurveStableLP.USDC_FXUSD),
    //         address(AddrClassicERC20.TOKEN_USDC),
    //         address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
    //         address(tgUSD),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0)
    //     ];
    //     swapParams = [
    //         [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
    //         [ZERO, uint256(1), uint256(1), uint256(10), uint256(2)],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO],
    //         [ZERO, ZERO, ZERO, ZERO, ZERO]
    //     ];
    // }

    function test_liquidator_curve_router_chainview_multi_quote() public {
        CurveQuote[] memory curveQuotes = new CurveQuote[](2);

        address[11] memory route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_USDC),
            address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
            address(tgUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        uint256[5][5] memory swapParams = [
            [ZERO, ZERO, uint256(6), uint256(10), uint256(2)],
            [ZERO, uint256(1), uint256(1), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        address[5] memory pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote1 = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});

        route = [
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrCurveStableLP.CRVUSD_USDC),
            address(AddrClassicERC20.TOKEN_CRVUSD),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        swapParams = [
            [ZERO, uint256(1), uint256(6), uint256(10), uint256(2)],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        pools = [address(0), address(0), address(0), address(0), address(0)];

        CurveQuote memory curveQuote2 = CurveQuote({_route: route, _swap_params: swapParams, _amount: 100 ether, _pools: pools});

        curveQuotes[0] = curveQuote1;
        curveQuotes[1] = curveQuote2;
        try new QuoteLiquidationRouter(curveQuotes) {} catch (bytes memory reason) {
            uint256[] memory results = abi.decode(removeFirst4Bytes(reason), (uint256[]));
            assertGt(results[0], 100 ether);
            assertGt(results[1], 100 ether);
            console.log(results[0]);
            console.log(results[1]);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function testSwapTokens() public {

     
        IERC20 tgUSD = lpDeploymentContext.tgUSD();
        address tgUSDAddress =address(tgUSD);
        address poolUSDCTgUSd = address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")); // Replace with actual address
        address marketDataCollatAddress = address(AddrCurveStableLP.USDC_FXUSD);
        
        IERC20 lpContract;

        // Define the routes for the swap
        address[11] memory routes = [address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];
        routes[0] = marketDataCollatAddress; // Collateral LP
        routes[1] = marketDataCollatAddress; // LP Collat => USDC (remove liquidity)
        routes[2] = address(AddrClassicERC20.TOKEN_USDC); // tgUSD Address
        routes[3] = poolUSDCTgUSd; // Pool USDC -> tgUSD
        routes[4] = tgUSDAddress; // tgUSD
        console.log(routes[0]);
        console.log(routes[1]);
        console.log(routes[2]);
        console.log(routes[3]);
        console.log(routes[4]);

        uint256[5][5] memory swapParams = [
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO],
            [ZERO, ZERO, ZERO, ZERO, ZERO]
        ];
        // Define the swap parameters
        swapParams[0] = [uint256(0), uint256(0), uint256(6), uint256(1), uint256(2)]; // Swap LP Collat => USDC (remove liquidity)
        swapParams[1] = [uint256(0), uint256(1), uint256(1), uint256(10), uint256(2)]; // Swap USDC => tgUSD

         address[5] memory zapPools = [address(0), address(0), address(0), address(0), address(0)];

    
        address userAddress = makeAddr("UsertestSwapTokens");
        deal(marketDataCollatAddress,userAddress, 4000 ether );
        vm.startPrank(userAddress); 

        ICurveRouter curveRouter = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);
        lpContract = IERC20(marketDataCollatAddress); 
        uint256 amountIn = 100 ether;

        uint256 estimate =  curveRouter.get_dy(routes, swapParams, amountIn, zapPools);
        lpContract.approve(address(curveRouter), amountIn);

        console.log("Balance Before:", lpContract.balanceOf(userAddress),tgUSD.balanceOf(userAddress));
        //Execute the exchange
        curveRouter.exchange(routes, swapParams, amountIn,  estimate, zapPools, userAddress) ;

        vm.stopPrank();
        console.log("Balance After:", lpContract.balanceOf(userAddress),tgUSD.balanceOf(userAddress));
      

        // Assert the expected behavior (you can modify this logic based on your expected output)
        //assert(balanceAfter > balanceBefore, "Balance after swap should be greater than before");
    }
}

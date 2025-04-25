// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract CurveRouterTest is MarketDeploymentContext {
    ICurveRouter ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    uint256 amount = 10 * 10 ** 18;

    //  "route": "USDC/fxUSD >> USDC/fxUSD >> USDC  >> USDC >> tgUSD-USDC* >> tgUSD* ",
    function test_curve_full_route2() external {
        address inLp = address(AddrCurveStableLP.USDC_fxUSD);
        string memory lpKey = "tgUSD-USDC";

        address[] memory route = new address[](11);
        route[0] = inLp;
        route[1] = inLp;
        route[2] = address(AddrClassicERC20.USDC);
        route[3] = address(lpDeploymentContext.tgUSDLPs(lpKey));
        route[4] = address(tgUSD);
        route[5] = address(0);
        route[6] = address(0);
        route[9] = address(0);
        route[10] = address(0);

        vm.startPrank(usr1);
        //USDC/crvUSD >> USDC/crvUSD >> crvUSD
        IERC20 tokenIn = IERC20(route[0]);
        deal(address(tokenIn), usr1, amount);
        tokenIn.approve(address(ROUTER), amount);
        uint256 allowance = tokenIn.allowance(usr1, address(ROUTER));

        // address[] memory route = Array.memoryAddress([address(tokenIn), address(pool), address(tokenOut)]);
        uint256[][] memory swapParams = new uint256[][](5);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(6), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);
        swapParams[4] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);
        // uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(6), uint256(10), uint256(2)]);
        // swapParams[0] = wrapToWStable;

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 1, routerSwap._pools, usr1);
    }

    //  "USDT/crvUSD >> USDT/crvUSD >> USDT  >> USDT >> USDT/USDC >> USDC  >> USDC >> USR/USDC >> USR  >> USR >> wUSR* >> wUSR*  >> wUSR* >> tgUSD-wUSR* >> tgUSD* ",
    function test_curve_full_route() external {
        string memory lpKey = "tgUSD-wUSR";

        address[] memory route = new address[](11);
        route[0] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
        route[1] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
        route[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        route[3] = 0x4f493B7dE8aAC7d55F71853688b1F7C8F0243C85;
        route[4] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        route[5] = 0x3eE841F47947FEFbE510366E4bbb49e145484195;
        route[6] = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110;
        route[7] = address(wUSR);
        route[8] = address(wUSR);
        route[9] = address(lpDeploymentContext.tgUSDLPs(lpKey));
        route[10] = address(tgUSD);

        vm.startPrank(usr1);
        //USDC/crvUSD >> USDC/crvUSD >> crvUSD
        IERC20 tokenIn = IERC20(route[0]);
        deal(address(tokenIn), usr1, amount);
        tokenIn.approve(address(ROUTER), amount);
        uint256 allowance = tokenIn.allowance(usr1, address(ROUTER));
        IERC20 pool = IERC20(address(AddrCurveStableLP.USDC_crvUSD));
        IERC20 tokenOut = IERC20(address(AddrClassicERC20.crvUSD));

        // address[] memory route = Array.memoryAddress([address(tokenIn), address(pool), address(tokenOut)]);
        uint256[][] memory swapParams = new uint256[][](5);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(6), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[2] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(0), uint256(9), uint256(1), uint256(0)]);
        swapParams[4] = Array.memoryUint256([uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)]);
        // uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(6), uint256(10), uint256(2)]);
        // swapParams[0] = wrapToWStable;

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 1, routerSwap._pools, usr1);
    }

    function test_curve() external {
        vm.startPrank(usr1);
        //USDC/crvUSD >> USDC/crvUSD >> crvUSD
        IERC20 tokenIn = IERC20(AddrCurveStableLP.USDC_crvUSD);
        deal(address(tokenIn), usr1, amount);
        tokenIn.approve(address(ROUTER), amount);
        IERC20 pool = IERC20(address(AddrCurveStableLP.USDC_crvUSD));
        IERC20 tokenOut = IERC20(address(AddrClassicERC20.crvUSD));

        address[] memory route = Array.memoryAddress([address(tokenIn), address(pool), address(tokenOut)]);
        uint256[][] memory swapParams = new uint256[][](1);
        uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(6), uint256(10), uint256(2)]);
        swapParams[0] = wrapToWStable;

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 1, routerSwap._pools, usr1);
    }

    function test_stable_to_wStable() external {
        vm.startPrank(usr1);

        IERC20 tokenIn = AddrClassicERC20.crvUSD;
        deal(address(tokenIn), usr1, amount);
        tokenIn.approve(address(ROUTER), amount);

        address[] memory route = Array.memoryAddress([address(tokenIn), address(wcrvUSD), address(wcrvUSD)]);
        uint256[][] memory swapParams = new uint256[][](1);
        uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[0] = wrapToWStable;

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 1, routerSwap._pools, usr1);
    }

    function test_stable_to_sStable() external {
        vm.startPrank(usr1);

        IERC20 tokenIn = AddrClassicERC20.frxUSD;
        IERC20 tokenOut = AddrERC4626.sfrxUSD;

        deal(address(tokenIn), usr1, amount);
        tokenIn.approve(address(ROUTER), amount);

        address[] memory route = Array.memoryAddress([address(tokenIn), address(tokenOut), address(tokenOut)]);
        uint256[][] memory swapParams = new uint256[][](1);
        uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[0] = wrapToWStable;

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 1, routerSwap._pools, usr1);
    }
}

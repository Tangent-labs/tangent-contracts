// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract CurveRouterTest is ConvexCurveContext {
    ICurveRouter constant ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    uint256 amount = 10 * 10 ** 9;
    // function setUp() public {
    //     // market = deployConvexCurveLPMarket(collatToken);
    // }

    function test_stable_to_wStable() external {
        vm.startPrank(usr1);

        IERC20 tokenIn = AddrClassicERC20.TOKEN_FRXUSD;
        deal(address(tokenIn), usr1, amount);
        address[] memory route = Array.memoryAddress([address(tokenIn), address(wfrxUSD), address(wfrxUSD)]);
        uint256[][] memory swapParams = new uint256[][](1);
        uint256[] memory wrapToWStable = Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]);
        swapParams[0] = wrapToWStable;

        tokenIn.approve(address(ROUTER), amount);

        CurveRouterSwap memory routerSwap = encoder.createCurveRouterStruct(route, swapParams, amount, 0, usr1);

        ROUTER.exchange(routerSwap._route, routerSwap._swap_params, amount, 0, routerSwap._pools, usr1);
    }
}

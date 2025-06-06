// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
contract LeverageCurveRoute is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    IStakingProxyERC20 stakingProxy;

    HLPManipulator hLpManipulator;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_leverage_on_curve_route() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 tgUSDToFlashMint = 20_000 ether;
        uint256 minCollatOut = 9_995 ether;

        deal(address(collatToken), address(usr1), collatToDeposit);
        collatToken.approve(address(market), MAX_UINT);

        // Leverage 1

        uint256[][] memory swapParams = new uint256[][](2);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(0), uint256(4), uint256(1), uint256(2)]);

        bytes memory routeCall = encoder.encodeLiquidateCallForCurveLP(
            encoder.createCurveRouterStruct(
                Array.memoryAddress(
                    [
                        address(tgUSD),
                        address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
                        address(AddrClassicERC20.USDC),
                        address(AddrCurveStableLP.USDC_crvUSD),
                        address(AddrCurveStableLP.USDC_crvUSD)
                    ]
                ),
                swapParams,
                tgUSDToFlashMint,
                0,
                address(market)
            )
        );

        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            minCollatOut,
            true,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routeCall})
        );

        // Leverage 2

        routeCall = encoder.encodeLiquidateCallForCurveLP(
            encoder.createCurveRouterStruct(
                Array.memoryAddress(
                    [
                        address(tgUSD),
                        address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")),
                        address(AddrClassicERC20.USDC),
                        address(AddrCurveStableLP.USDC_crvUSD),
                        address(AddrCurveStableLP.USDC_crvUSD)
                    ]
                ),
                swapParams,
                20_000 ether,
                0,
                address(market)
            )
        );

        market.leverage(
            0,
            tgUSDToFlashMint,
            minCollatOut,
            true,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(AddrRouter.ROUTER_CURVE), routerCall: routeCall})
        );
    }
}

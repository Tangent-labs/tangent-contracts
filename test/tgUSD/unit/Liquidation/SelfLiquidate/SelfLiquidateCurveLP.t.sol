// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateCurveLP is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    ICurveStableSwapNG public lpTgUSD_USDC;
    ICurveStableSwapNG public lpTgUSD_wfrxUSD;

    uint256[][] public swapParams;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        lpTgUSD_USDC = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        lpTgUSD_wfrxUSD = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD");

        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1);

        uint256 zero = 0;

        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);
        swapParams.push(unwrapLPToUSDC);
        swapParams.push(swapUsdcToTgUSD);
    }

    function test_selfLiquidate_all_position_curveLP() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_250 ether, true, address(0));

        irCalculator.checkpointIR(address(market));

        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        market.selfLiquidate(
            collatDeposited,
            MAX_UINT,
            address(AddrRouter.ROUTER_CURVE),
            4_250 ether,
            encoder.encodeLiquidateCallForCurveLP(
                encoder.createCurveRouterStruct(
                    Array.memoryAddress(
                        [
                            address(AddrCurveStableLP.CRVUSD_USDC),
                            address(AddrCurveStableLP.CRVUSD_USDC),
                            address(AddrClassicERC20.TOKEN_USDC),
                            address(lpTgUSD_USDC),
                            address(tgUSD)
                        ]
                    ),
                    swapParams,
                    collatToDump,
                    4_250 ether,
                    usr1
                )
            )
        );

        // Liquidation passes after IR increased the user debt over the liquidation threshold

        assertEq(market.userDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }
}

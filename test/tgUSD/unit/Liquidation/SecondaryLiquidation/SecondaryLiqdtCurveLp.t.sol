// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SecondaryLiqdtCurveLp is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    ICurveStableSwapNG public lpTgUSD_USDC;
    ICurveStableSwapNG public lpTgUSD_wfrxUSD;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        lpTgUSD_USDC = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        lpTgUSD_wfrxUSD = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD");

        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1);
    }

    function test_secondaryLiquidator_liquidate_with_secondary_liquidator_crvUSD_USDC() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_250 ether, true, address(0));

        // Dumps tgUSD for USDC => Depegs tgUSD
        hLpManipulator.dumpCrvPool(lpTgUSD_USDC, 1, 0, 500_000 ether);
        hLpManipulator.dumpCrvPool(lpTgUSD_wfrxUSD, 1, 0, 500_000 ether);

        vm.startPrank(usr1);

        skip(800);

        // Update IR on the market
        market.checkpointIR();

        (uint256 ir, uint256 timestamp) = IIRCalculator(irCalculator).irCheckpoint(address(market));

        assertGt(ir, 40 ether, "IR skyrockets as peg of tgUSD is low");

        // Skip time to be able to liquidate
        skip(100 days);

        assertLe(market.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(market.positionDebt(usr1), (collatDeposited * 93) / 100, "Debt is getting over the 93% of the collateral");

        // Liquidation passes after IR increased the user debt over the liquidation threshold

        ICurveStableSwapNG collatLp = ICurveStableSwapNG(address(collatToken));

        uint256 zero = 0;

        uint256 collatToDump = market.collateralBalances(usr1);
        uint256 amountToRetrive = collatLp.calc_withdraw_one_coin(collatToDump, 0);

        address[] memory route = Array.memoryAddress(
            [address(AddrCurveStableLP.CRVUSD_USDC), address(AddrCurveStableLP.CRVUSD_USDC), address(AddrClassicERC20.TOKEN_USDC), address(lpTgUSD_USDC), address(tgUSD)]
        );
        uint256[][] memory swapParams = new uint256[][](2);
        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);

        swapParams[0] = unwrapLPToUSDC;
        swapParams[1] = swapUsdcToTgUSD;

        bytes memory callToSecondaryLiquidator = encoder.encodeLiquidateCallForCurveLP(
            encoder.createCurveRouterStruct(route, swapParams, collatToDump, 0, usr1),
            encoder.createEmptyMintAndSwapWStable()
        );

        market.liquidate(usr1, MAX_UINT, address(AddrCurveStableLP.ROUTER_CURVE), 0, callToSecondaryLiquidator);

        assertEq(market.positionDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }
}

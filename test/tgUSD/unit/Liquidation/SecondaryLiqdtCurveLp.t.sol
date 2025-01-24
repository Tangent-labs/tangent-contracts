// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import {RemoveLiquidityCollateral} from "../../../../src/interfaces/internals/tgUSD/ICurveLPLiquidator.sol";

contract SecondaryLiqdtCurveLp is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1, market);
    }

    function test_liquidate_with_secondary_liquidator() external {
        hDeposit.depositAndBorrow(10_000 ether, 8_500 ether, true, address(0));

        // Dumps tgUSD for USDC => Depegs tgUSD
        hLpManipulator.dumpCrvPool(tgUSD_USDC_Lp, 1, 0, 900_000 ether);

        vm.startPrank(usr1);

        skip(800);

        // Update IR on the market
        market.checkpointIR();

        assertGt(market.lastIR(), 40 ether, "IR skyrockets as peg of tgUSD is low");

        // Skip time to be able to liquidate
        skip(100 days);

        assertLe(market.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(market.positionDebt(usr1), 9_300 ether, "Debt is getting over the 93% of the collateral");

        // Liquidation passes after IR increased the user debt over the liquidation threshold

        ICurveStableSwapNG lp = ICurveStableSwapNG(address(collatToken));

        uint256 zero = 0;

        uint256 collatToDump = market.collateralBalances(usr1);
        uint256 amountToRetrive = lp.calc_withdraw_one_coin(collatToDump, 0);

        address[] memory route = Array.memoryAddress(
            [address(AddrCurveStableLP.CRVUSD_USDC), address(AddrCurveStableLP.CRVUSD_USDC), address(AddrClassicERC20.TOKEN_USDC), address(tgUSD_USDC_Lp), address(tgUsd)]
        );
        uint256[][] memory swapParams = new uint256[][](2);
        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);

        swapParams[0] = unwrapLPToUSDC;
        swapParams[1] = swapUsdcToTgUSD;

        bytes memory callToSecondaryLiquidator = encoder.encodeLiquidateCallForCurveLP(encoder.createCurveRouterStruct(route, swapParams, collatToDump, 0, usr1), 2000000);
        market.liquidate(usr1, MAX_UINT, address(curveLPLiquidator), callToSecondaryLiquidator);
        assertERC20Tracking();

        assertEq(market.positionDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }
}

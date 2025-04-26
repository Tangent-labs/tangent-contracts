// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
contract SecondaryLiqdtCurveLp is MarketDeploymentContext {
    ConvexCrvLPMarket public market_crvUSD_USDC;
    ConvexFxnLPMarket public market_fxUSD_USDC;

    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit_crvUSD_USDC;
    HDepositConvexFxnLP public hDeposit_fxUSD_USDC;

    HLpManipulator public hLpManipulator;
    ICurveStableSwapNG public lpTgUSD_USDC;
    ICurveStableSwapNG public lpTgUSD_wfrxUSD;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        lpTgUSD_USDC = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        lpTgUSD_wfrxUSD = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD");

        market_crvUSD_USDC = deployConvexCurveLPMarket(collatToken);
        market_fxUSD_USDC = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);

        hDeposit_crvUSD_USDC = new HDepositConvexCrvLP(usr1, market_crvUSD_USDC);
        hDeposit_fxUSD_USDC = new HDepositConvexFxnLP(usr1, market_fxUSD_USDC);

        hLpManipulator = new HLpManipulator(usr1);
    }

    function test_secondaryLiquidator_liquidate_with_secondary_liquidator_crvUSD_USDC() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit_crvUSD_USDC.depositAndBorrow(collatDeposited, 4_250 ether, true);

        irCalculator.checkpointIR(address(market_crvUSD_USDC));

        // Dumps tgUSD for USDC => Depegs tgUSD
        hLpManipulator.dumpCrvPool(lpTgUSD_USDC, 1, 0, 400_000 ether);
        hLpManipulator.dumpCrvPool(lpTgUSD_wfrxUSD, 1, 0, 400_000 ether);

        skip(800);

        // Update IR on the market
        irCalculator.checkpointIR(address(market_crvUSD_USDC));

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market_crvUSD_USDC));

        assertGt(ir, 0.04 ether, "IR skyrockets as peg of tgUSD is low");

        // Skip time to be able to liquidate
        skip(50 days);

        assertLe(market_crvUSD_USDC.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(market_crvUSD_USDC.userDebt(usr1), (collatDeposited * 93) / 100, "Debt is getting over the 93% of the collateral");

        hLpManipulator.dumpCrvPool(lpTgUSD_wfrxUSD, 0, 1, 20_000 ether);

        // Prevent the next call to fail
        vm.store(address(tgUSD), bytes32(uint256(2)), bytes32(uint256(100_000 ether)));

        vm.startPrank(usr2);

        // Liquidation passes after IR increased the user debt over the liquidation threshold

        uint256 zero = 0;

        uint256 collatToDump = market_crvUSD_USDC.collateralBalances(usr1);

        uint256[][] memory swapParams = new uint256[][](2);
        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([zero, zero, uint256(6), uint256(10), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(10), uint256(2)]);

        swapParams[0] = unwrapLPToUSDC;
        swapParams[1] = swapUsdcToTgUSD;

        irCalculator.mintIR();

        market_crvUSD_USDC.liquidate(
            usr1,
            collatDeposited,
            address(AddrRouter.ROUTER_CURVE),
            5_000 ether,
            encoder.encodeLiquidateCallForCurveLP(
                encoder.createCurveRouterStruct(
                    Array.memoryAddress(
                        [address(AddrCurveStableLP.USDC_crvUSD), address(AddrCurveStableLP.USDC_crvUSD), address(AddrClassicERC20.USDC), address(lpTgUSD_USDC), address(tgUSD)]
                    ),
                    swapParams,
                    collatToDump,
                    5_000 ether,
                    usr2
                )
            )
        );

        assertEq(market_crvUSD_USDC.userDebt(usr1), 0);
        assertEq(market_crvUSD_USDC.totalDebt(), 0);
        assertEq(market_crvUSD_USDC.totalCollateral(), 0);
        assertEq(market_crvUSD_USDC.collateralBalances(usr1), 0);
        vm.stopPrank();
    }

    function test_secondaryLiquidator_liquidate_with_secondary_liquidator_fxUSD_USDC() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit_fxUSD_USDC.depositAndBorrow(collatDeposited, 4_250 ether, true, address(0));

        irCalculator.checkpointIR(address(market_fxUSD_USDC));

        // Dumps tgUSD for USDC => Depegs tgUSD
        hLpManipulator.dumpCrvPool(lpTgUSD_USDC, 1, 0, 400_000 ether);
        hLpManipulator.dumpCrvPool(lpTgUSD_wfrxUSD, 1, 0, 400_000 ether);

        skip(800);

        // Update IR on the market
        irCalculator.checkpointIR(address(market_fxUSD_USDC));

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market_fxUSD_USDC));

        assertGt(ir, 0.04 ether, "IR skyrockets as peg of tgUSD is low");

        // Skip time to be able to liquidate
        skip(35 days);

        assertLe(market_fxUSD_USDC.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        assertGe(market_fxUSD_USDC.userDebt(usr1), (collatDeposited * 93) / 100, "Debt is getting over the 93% of the collateral");

        hLpManipulator.dumpCrvPool(lpTgUSD_wfrxUSD, 0, 1, 20_000 ether);

        // Prevent the next call to fail
        vm.store(address(tgUSD), bytes32(uint256(2)), bytes32(uint256(100_000 ether)));

        vm.startPrank(usr2);

        // Liquidation passes after IR increased the user debt over the liquidation threshold

        uint256 zero = 0;

        uint256 collatToDump = market_fxUSD_USDC.collateralBalances(usr1);

        uint256[][] memory swapParams = new uint256[][](2);
        uint256[] memory unwrapLPToUSDC = Array.memoryUint256([uint256(1), zero, uint256(6), uint256(1), uint256(2)]);
        uint256[] memory swapUsdcToTgUSD = Array.memoryUint256([zero, uint256(1), uint256(1), uint256(1), uint256(2)]);

        swapParams[0] = unwrapLPToUSDC;
        swapParams[1] = swapUsdcToTgUSD;

        irCalculator.mintIR();

        // skip(365 days);

        market_fxUSD_USDC.liquidate(
            usr1,
            collatDeposited,
            5_000 ether,
            ZapStruct({
                router: address(AddrRouter.ROUTER_CURVE),
                routerCall: encoder.encodeLiquidateCallForCurveLP(
                    encoder.createCurveRouterStruct(
                        Array.memoryAddress(
                            [address(AddrCurveStableLP.USDC_fxUSD), address(AddrCurveStableLP.USDC_fxUSD), address(AddrClassicERC20.USDC), address(lpTgUSD_USDC), address(tgUSD)]
                        ),
                        swapParams,
                        collatToDump,
                        5_000 ether,
                        usr2
                    )
                )
            })
        );

        assertEq(market_fxUSD_USDC.userDebt(usr1), 0);
        assertEq(market_fxUSD_USDC.totalDebt(), 0);
        assertEq(market_fxUSD_USDC.totalCollateral(), 0);
        assertEq(market_fxUSD_USDC.collateralBalances(usr1), 0);

        vm.stopPrank();
    }
}

 // // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;
// import "../../../contexts/MarketDeploymentContext.sol";

// contract SelfLiquidateCurveGaugeMarket is MarketDeploymentContext {
//     using SafeERC20 for IERC20Metadata;

//     CurveGaugeMarket public market;
//     IGauge public gaugeToken;
//     IERC20Metadata public collatToken;

//     uint256 minimumLoan;
//     function setUp() public {
//         gaugeToken = AddrCurveGauge.PYUSD_USDC;
//         collatToken = AddrCurveStableLP.PYUSD_USDC;
//         IERC20[] memory tokens = new IERC20[](1);
//         tokens[0] = AddrClassicERC20.PYUSD;
//         market = deployCurveGaugeMarket(collatToken, gaugeToken, tokens);
//         minimumLoan = market.minimumLoan();
//     }

//     function test_selfLiquidate_curveGaugeMarket() external {
//         vm.startPrank(usr1);
//         uint256 amountIn = 10_000 ether;
//         uint256 borrowedAmount = 5_000 ether;
//         uint256 usgToRepay = 1_000 ether;
//         uint256 collatToLiquidate = 1_200 ether;
//         uint256 dumpQuote = 1050 ether;

//         deal(address(usg), address(zappingProxy), dumpQuote);

//         gaugeToken.approve(address(market), MAX_UINT);
//         market.depositAndBorrow(amountIn, borrowedAmount, true);

//         //  Verify that gauge token are transfered from user to market directly

//         verifyLostERC20(gaugeToken, address(market), collatToLiquidate, "Gauge removed from market");
//         verifyBurnERC20(usg, usgToRepay, "USG burnt");
//         verifyReceiveERC20(usg, usr1, dumpQuote - usgToRepay, "Leftover of USG received by User");

//         market.selfLiquidate(
//             SelfLiquidateIn({collatAmountToLiquidate: collatToLiquidate, usgToRepay: usgToRepay, maxUsgToBurn: MAX_UINT, minUsgOut: 1_000 ether}),
//             ZapStruct({router: address(usg), routerCall: abi.encodeWithSelector(IERC20.transfer.selector, address(usr1), dumpQuote)})
//         );

//         assertEq(market.totalCollateral(), amountIn - collatToLiquidate);
//         assertEq(market.collateralBalances(usr1), amountIn - collatToLiquidate);
//         assertEq(market.userDebt(usr1), borrowedAmount - usgToRepay);
//         assertERC20Tracking();

//         //  Verify that gauge token are unwrapped to LP and sent to user
//         verifyLostERC20(gaugeToken, address(market), market.totalCollateral(), "Gauge transfered from Market");
//         verifyReceiveERC20(gaugeToken, usr1, amountIn - collatToLiquidate, "Gauge received by User 1");

//         verifyLostERC20(gaugeToken, address(market), market.totalCollateral(), "USG burnt");
//         verifyBurnERC20(usg, market.userDebt(usr1), "USG burnt from usr1");

//         market.repayAndWithdraw(market.totalCollateral(), MAX_UINT, true);
//         assertEq(market.totalCollateral(), 0);
//         assertEq(market.collateralBalances(usr1), 0);
//         assertERC20Tracking();
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../../handler/Features/HProcessRewards.sol";

contract LiquidateDebtGoHigh is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    HLPManipulator public hLpManipulator;
    ICurveStableSwapNG public lp;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        lp = lpDeploymentContext.USGLPs("USG-USDC");
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLPManipulator(usr1);
    }

    function test_liquidate_all_after_USG_depegs() external {
        uint256 collatDeposited = 5_000 ether;
        hDeposit.depositAndBorrow(collatDeposited, 4_248 ether);

        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, 0, ZapStruct({router: address(0), routerCall: ""}));
        vm.stopPrank();

        // Dumps USG for USDC => Depegs USG
        hLpManipulator.dumpCrvPool(lp, 1, 0, 4_500 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, MAX_UINT, 0, ZapStruct({router: address(0), routerCall: ""}));

        // assertLt(lp.last_price(0), 991 * 10 ** 15, "Last price dropped hard");

        // skip(800);
        // assertLt(USGOracle.price(), 995 * 10 ** 15, "Price is goig down brutally after EMA is following");

        // // Update IR on the market
        // market.checkpointIR();

        // assertGt(market.lastIR(), 40 ether, "IR should skyrocket as peg of USG is low");

        // // Go to the limit of the health ratio
        // skip(25 days);
        // // Liquidation doesn't pass, the HR is very close to 1 but still >
        // vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        // market.liquidate(usr1, MAX_UINT, address(0), 0, "");

        // // The position from this point liquidable
        // skip(15 days);

        // deal(address(USG), usr1, market.userDebt(usr1));

        // assertLe(market.healthRatio(usr1), 1 ether, "Health ratio is lower than 1");
        // assertGe(market.userDebt(usr1), 4650 ether, "Debt is getting over the 93% of the collateral");

        // verifyLostERC20(USG, usr1, market.userDebt(usr1), "USG burnt from sender");
        // verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "USG burnt from sender");
        // // Liquidation passes after IR increased the user debt over the liquidation threshold
        // market.liquidate(usr1, MAX_UINT, address(0), 0, "");
        // assertERC20Tracking();

        // assertEq(market.userDebt(usr1), 0);
        // assertEq(market.totalDebt(), 0);

        // vm.stopPrank();
    }
}

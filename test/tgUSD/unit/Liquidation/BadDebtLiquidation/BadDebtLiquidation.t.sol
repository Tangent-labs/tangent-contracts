// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../../src/tgUSD/Market/abstract/DebtIR.sol";
import "../../../../utils/ERC20BalanceChanges.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract BadDebtLiquidation is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HLpManipulator public hLpManipulator;

    ERC20BalanceChanges public balanceChanges;

    uint256 collatDeposited = 20 ether;
    uint256 tgUSDBorrowed = 13_000 ether;
    uint256 badDebtToRepay = 7_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.WETH_frxETH;
        market = deployConvexCurveLPMarket(collatToken);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLpManipulator(usr1);

        hDeposit.depositAndBorrow(collatDeposited, tgUSDBorrowed, true, address(0));
    }

    function test_liquidateBadDebt_fails_because_no_bad_debt() external {
        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);

        // Liquidation doesn't pass because there is no bad debt
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionWithoutBadDebt.selector));
        market.liquidateBadDebt(usr1);
    }

    function test_liquidateBadDebt_a_position_in_bad_debt() external {
        vm.startPrank(usr1);

        assertGt(market.positionValue(usr1), market.userDebt(usr1), "Position value is still bigger than the debt");

        // Dump a lot of FRXETH in the LP to depeg FRXETH
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.WETH_frxETH, 1, 0, 1_400 ether);

        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionWithoutBadDebt.selector));
        market.liquidateBadDebt(usr1);

        skip(30 days);

        assertLt(market.positionValue(usr1), market.userDebt(usr1), "Position value is now lower than the debt");

        verifyReceiveERC20(collatToken, controlTower.feeTreasury(), collatDeposited, "Collateral is requisitioned by the DAO");

        uint256 debtToRepay = market.userDebt(usr1);
        // Liquidation passes
        market.liquidateBadDebt(usr1);
        assertERC20Tracking();

        assertEq(market.totalCollateral(), 0, "No more collateral on the market");
        assertEq(market.positionValue(usr1), 0, "Position value is now 0");
        assertEq(market.userDebt(usr1), 0, "Position debt is now 0");

        assertEq(market.badDebt(), debtToRepay, "Amount of bad debt is now equal to the debt of the position liquidated");

        skip(1 weeks);

        irCalculator.checkpointIR(address(market));

        vm.startPrank(usr2);
        hDeposit.setMsgSender(usr2);

        hLpManipulator.dumpCrvPool(AddrCurveStableLP.WETH_frxETH, 0, 1, 1_400 ether);

        skip(1 days);

        hDeposit.depositAndBorrow(10 ether, tgUSDBorrowed, true, address(0));

        verifyLostERC20(tgUSD, usr2, badDebtToRepay, "Verify that the usr2 loose the tgUSD");
        verifyBurnERC20(tgUSD, badDebtToRepay, "Verify that the supply of tgUSD is reduced");
        vm.prank(usr2);
        market.repayBadDebt(badDebtToRepay);
        assertERC20Tracking();

        assertEq(market.badDebt(), tgUSDBorrowed - badDebtToRepay, "Check that bad debt has been reduced");

        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(DebtIR.RepayMoreThanBadDebt.selector));
        market.repayBadDebt(badDebtToRepay);
        vm.stopPrank();

        uint256 remainingDebt = market.badDebt();
        verifyLostERC20(tgUSD, usr2, remainingDebt, "Verify that the usr2 loose the tgUSD");
        verifyBurnERC20(tgUSD, remainingDebt, "Verify that the supply of tgUSD is reduced");
        vm.prank(usr2);
        market.repayBadDebt(remainingDebt);
        assertERC20Tracking();
        assertEq(market.badDebt(), 0, "BadDebt is fully recovered");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/MarketDeploymentContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";
import "../handler/Features/HProcessRewards.sol";
import "../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract CurveConvexMarketWithoutConvex is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    function setUp() public {
        collatToken = AddrCurveStableLP.sDAI_sUSDe;
        market = deployConvexCurveLPMarket(collatToken, false);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
    }

    //
    function test_deposit_and_borrow_stake() external {
        uint256 collatDeposited1 = 5_000 ether;
        uint256 borrowedAmount1 = 3_440 ether;

        verifyLostERC20(collatToken, usr1, collatDeposited1, "Verify that user sent its LP");
        verifyMintERC20(tgUSD, borrowedAmount1, "tgUSD need to be minted");
        verifyReceiveERC20(tgUSD, usr1, borrowedAmount1, "User receives the borrowed amount");

        vm.startSnapshotGas("Deposit And Borrow", "On a Curve LP not linked to Convex");
        hDeposit.depositAndBorrow(collatDeposited1, borrowedAmount1, true);
        vm.stopSnapshotGas("Deposit And Borrow", "On a Curve LP not linked to Convex");

        assertERC20Tracking();

        assertEq(market.collateralBalances(usr1), collatDeposited1, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), collatDeposited1, "Total collateral is not right");
        assertEq(market.userDebt(usr1), borrowedAmount1, "Position debt should be equal to the borrowed amount");
        assertEq(market.userDebtShares(usr1), borrowedAmount1, "Position debt index should be 0");
        assertEq(market.totalDebt(), borrowedAmount1, "Total debt should be 0");
        assertEq(market.socFeePending(), 0);

        hDeposit.depositAndBorrow(collatDeposited1, borrowedAmount1, false);

        skip(15 days);
        vm.startPrank(usr1);

        // Try to withdraw

        verifyReceiveERC20(collatToken, usr1, collatDeposited1, "Retrieve fully the collateral");
        verifyLostERC20(collatToken, address(market), collatDeposited1, "Withdraw the collateral from the market");
        market.repayAndWithdraw(collatDeposited1, market.userDebt(usr1));
        assertERC20Tracking();

        rewardAccumulator.processRewards(address(market), usr1);
    }
}

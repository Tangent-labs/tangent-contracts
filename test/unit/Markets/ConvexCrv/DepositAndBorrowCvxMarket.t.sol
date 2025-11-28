// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract DepositAndBorrowCvxMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
    }

    //
    function test_deposit_and_borrow_stake() external {
        uint256 collatDeposited1 = 5_000 ether;
        uint256 borrowedAmount1 = 3_440 ether;

        verifyReceiveERC20(market.cvxRewardToken(), address(market), collatDeposited1, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.USDC_crvUSD, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(AddrCurveStableLP.USDC_crvUSD, usr1, collatDeposited1, "Verify that user sent its LP");
        verifyMintERC20(usg, borrowedAmount1, "USG are not minted");
        verifyReceiveERC20(usg, usr1, borrowedAmount1, "User receives the borrowed amount");

        vm.startSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");
        hDeposit.depositAndBorrow(collatDeposited1, borrowedAmount1, false);
        vm.stopSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");

        assertEq(market.collateralBalances(usr1), collatDeposited1, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), collatDeposited1, "Total collateral is not right");
        assertEq(marketViewer.userDebt(market, usr1), borrowedAmount1, "Position debt should be equal to the borrowed amount");
        assertEq(market.userDebtShares(usr1), borrowedAmount1, "Position debt index should be 0");
        assertEq(marketViewer.totalDebt(market), borrowedAmount1, "Total debt should be 0");

        skip(15 days);

        uint256 collatDeposited2 = 8_000 ether;
        uint256 borrowedAmount2 = 6_000 ether;

        verifyReceiveERC20(market.cvxRewardToken(), address(market), collatDeposited2, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.USDC_crvUSD, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(AddrCurveStableLP.USDC_crvUSD, usr2, collatDeposited2, "Verify that user sent its LP");
        verifyReceiveERC20(usg, usr2, borrowedAmount2 + 12, "User receives 50 USG");

        hDeposit.setMsgSender(usr2);
        hDeposit.depositAndBorrow(collatDeposited2, borrowedAmount2, false);

        assertEq(market.collateralBalances(usr2), collatDeposited2, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), collatDeposited1 + collatDeposited2, "Total collateral is not right");

        assertApproxEqAbs(marketViewer.userDebt(market, usr2), borrowedAmount2, 1, "Position debt displays the real debt for a user");

        assertEq(market.totalDebtShares(), market.userDebtShares(usr1) + market.userDebtShares(usr2), "Total Debt shares equals sum of all user debt shares");

        assertApproxEqAbs(marketViewer.totalDebt(market), marketViewer.userDebt(market, usr1) + marketViewer.userDebt(market, usr2), 1, "Total Debt equals sum of all debt");

        skip(1 days);
    }
}

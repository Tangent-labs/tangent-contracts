// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../../../handler/Features/ConvexCrv/HWithdrawConvexCrvLP.sol";

contract WithdrawCvxMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HWithdrawConvexCrvLP public hWithdraw;
    HBorrow public hBorrow;

    uint256 amountIn = 10_000 ether;
    uint256 borrowedAmount = 5_000 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
        hWithdraw = new HWithdrawConvexCrvLP(usr1, market, usg, marketViewer);
    }

    function test_withdraw_fully() external {
        hDeposit.depositAndBorrow(amountIn, borrowedAmount, false);
        vm.prank(usr1);
        market.repay(usr1, borrowedAmount);

        verifyLostERC20(market.cvxRewardToken(), address(market), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyBurnERC20(market.cvxRewardToken(), amountIn, "Verify that Cvx Reward tokens are burnt");
        verifyReceiveERC20(collatToken, usr1, amountIn, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        hWithdraw.withdraw(amountIn, false);
        vm.stopSnapshotGas();

        assertERC20Tracking();
    }

    function test_withdraw_partial() external {
        hDeposit.depositAndBorrow(amountIn, borrowedAmount, false);

        uint256 withdrawnAmount = 1_000 ether;

        verifyLostERC20(market.cvxRewardToken(), address(market), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        verifyBurnERC20(market.cvxRewardToken(), withdrawnAmount, "Verify that Cvx Reward tokens are burnt");
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        hWithdraw.withdraw(withdrawnAmount, false);
        vm.stopSnapshotGas();

        assertERC20Tracking();
    }
}

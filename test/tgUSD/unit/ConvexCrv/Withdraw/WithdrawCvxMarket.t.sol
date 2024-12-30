// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";

contract WithdrawCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HWithdrawConvexCrvLP public hWithdraw;
    HBorrow public hBorrow;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hWithdraw = new HWithdrawConvexCrvLP(usr1, market);

        minimumLoan = market.minimumLoan();
    }

    function test_withdraw_fully_from_staked() external {
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        hDeposit.depositAndBorrow(amountIn, borrowedAmount, true, address(0));

        uint256 withdrawnAmount = 1_000 ether;

        verifyLostERC20(market.cvxRewardToken(), address(market), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        verifyBurnERC20(market.cvxRewardToken(), withdrawnAmount, "Verify that Cvx Reward tokens are burnt");
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        hWithdraw.withdraw(withdrawnAmount);
        vm.stopSnapshotGas();

        assertERC20Tracking();
    }

    // function test_withdraw_fully_from_not_staked() external {
    //     uint256 amountIn = 10_000 ether;
    //     uint256 borrowedAmount = 5_000 ether;
    //     console.log("usr1", usr1);

    //     hDeposit.depositAndBorrow(amountIn, borrowedAmount, false);

    //     uint256 withdrawnAmount = 1_000 ether;

    //     verifyLostERC20(collatToken, address(market), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
    //     verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

    //     vm.startSnapshotGas("Withdraw", "Withdraw fully from unstaked collat");
    //     hWithdraw.withdraw(withdrawnAmount);
    //     vm.stopSnapshotGas();

    //     assertERC20Tracking();

    //     assertEq(market.collateralBalances(usr1), amountIn - withdrawnAmount - market.socFeePending());
    // }

    // function test_withdraw_from_staked_and_not_staked() external {
    //     uint256 amountInStaked = 10_000 ether;
    //     uint256 borrowedAmount1 = 5_000 ether;
    //     uint256 borrowedAmount2 = 1_000 ether;
    //     hDeposit.depositAndBorrow(amountInStaked, borrowedAmount1, true);
    //     hDeposit.depositAndBorrow(amountInStaked, borrowedAmount2, false);

    //     uint256 withdrawnAmount = 12_000 ether;
    //     uint256 availableAmount = market.collatToken().balanceOf(address(market)) - market.socFeePending();
    //     uint256 amountWithdrawnFromConvex = withdrawnAmount - availableAmount;
    //     uint256 amountWithdrawnDirectly = withdrawnAmount - amountWithdrawnFromConvex;
    //     verifyLostERC20(market.cvxRewardToken(), address(market), amountWithdrawnFromConvex, "Verify that we withdraw the right amount of Cvx Reward");
    //     verifyBurnERC20(market.cvxRewardToken(), amountWithdrawnFromConvex, "Verify that Cvx Reward tokens are burnt");

    //     verifyLostERC20(collatToken, address(market), amountWithdrawnDirectly, "Verify that we withdraw the right amount of LP unstaked Cvx Reward tokens");
    //     verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

    //     vm.startSnapshotGas("Withdraw", "Withdraw from staked and unstaked collat");
    //     hWithdraw.withdraw(withdrawnAmount);
    //     vm.stopSnapshotGas();

    //     assertERC20Tracking();

    //     assertEq(market.collateralBalances(usr1), 2 * amountInStaked - withdrawnAmount - market.socFeePending());
    // }
}

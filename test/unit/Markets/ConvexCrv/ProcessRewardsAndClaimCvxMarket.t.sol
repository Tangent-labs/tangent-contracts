// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract ProcessRewardsAndClaimCvxMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    ConvexFxnLPMarket public market2;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HProcessRewards public hRewards2;
    HDepositConvexCrvLP public hDeposit;
    HDepositConvexFxnLP public hDeposit2;

    HBorrow public hBorrow;
    uint256 minimumLoan;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);
        market2 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hRewards2 = new HProcessRewards(usr1, market2, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hDeposit2 = new HDepositConvexFxnLP(usr1, market2, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
        minimumLoan = market.minimumLoan();
    }

    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer(true) * 85_000);
    }

    function test_processRewards_claim_simple(uint256 collatDeposited, uint256 borrowedAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited, false);

        vm.startPrank(usr1);
        hBorrow.borrow(usr2, borrowedAmount);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);

        skip(7 days);
        vm.startPrank(usr1);
        rewardAccumulator.claimSimple(address(market));

        rewardAccumulator.claimCutFees(rewardAccumulator.getRewardTokens(address(market)));

        assertLt(rewardAccumulator.rewardTokens(address(market), 0).balanceOf(address(rewardAccumulator)), 5_000_000);

        vm.stopPrank();
    }

    function test_processRewards_claimMultiple(uint256 collatDeposited, uint256 borrowedAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited, false);

        hDeposit2.deposit(usr1, collatDeposited, false);

        vm.startPrank(usr1);
        hBorrow.borrow(usr2, borrowedAmount);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);
        hRewards2.processRewards(usr2);

        skip(7 days);
        vm.startPrank(usr1);

        rewardAccumulator.claimMultiple(Array.memoryAddress([address(market), address(market2)]), 3);
        rewardAccumulator.claimCutFees(rewardAccumulator.getRewardTokens(address(market)));

        assertLt(rewardAccumulator.rewardTokens(address(market), 0).balanceOf(address(rewardAccumulator)), 5_000_000);

        vm.stopPrank();
    }
}

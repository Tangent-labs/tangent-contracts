// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../handler/Features/HProcessRewards.sol";
contract ProcessRewardsCvxFxnMarket is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    uint256 minimumLoan;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator);
        hDeposit = new HDepositConvexFxnLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();
    }

    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * 85_000);
    }

    function test_processRewards_claim(uint256 collatDeposited, uint256 borrowedAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited);

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

        assertLt(rewardAccumulator.rewardTokens(address(market), 0).balanceOf(address(rewardAccumulator)), 10 ** 7);

        vm.stopPrank();
    }
}

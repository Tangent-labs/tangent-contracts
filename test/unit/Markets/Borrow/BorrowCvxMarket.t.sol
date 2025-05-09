// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract BorrowCvxMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HRepay public hRepay;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hRepay = new HRepay(usr1, market);

        minimumLoan = market.minimumLoan();
    }
    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * market.maxLTV());
    }

    //TODO Test here
    function test_borrow_consistency() external {
        // uint256 collatDeposited = 100_000 ether;
        // uint256 borrowedAmount1 = 60_000 ether;
        // uint256 borrowedAmount2 = 10_000 ether;
        // uint256 repayAmount1 = 50_000 ether;
        // uint256 repayAmount2 = 50_000 ether;
        // hDeposit.deposit(usr1, collatDeposited, true);
        // hBorrow.borrow(usr1, borrowedAmount1);
        // // assertEq(market.positionDebt(usr1), market.totalDebt());
        // // assertEq(market.positionDebt(usr1), borrowedAmount1);
        // skip(365 days);
        // // assertEq(market.positionDebt(usr1), market.totalDebt());
        // (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));
        // uint256 interestGenerated = (borrowedAmount1 * ir) / 1e18;
        // uint256 positionDebt1 = borrowedAmount1 + interestGenerated; // 60 000 + 60 000 * 0.04 =60 000 + 2 400 = 62 400
        // assertEq(market.positionDebt(usr1), borrowedAmount1 + interestGenerated, "Position debt increased with interest rate");
        // hBorrow.borrow(usr1, borrowedAmount2);
        // // assertEq(market.positionDebt(usr1), market.totalDebt());
        // // assertEq(market.userDebtShares(usr1), market.totalDebtShares());
        // assertApproxEqAbs(market.positionDebt(usr1), positionDebt1 + borrowedAmount2, 1, "Position debt increased with interest rate"); // 62400 + 10000 = 72400
        // uint256 interestGeneratedExpected2 = ((positionDebt1 + borrowedAmount2) * market.lastIR()) / 1e18;
        // skip(365 days);
        // assertEq(market.totalDebt(), positionDebt1 + borrowedAmount2 + interestGeneratedExpected2, "Pouloulou"); // 72400 + 72400*0.04 = 75296
        // assertEq(market.positionDebt(usr1), market.totalDebt());
    }
    function test_borrow(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan + 1, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited, true);

        verifyMintERC20(tgUSD, borrowedAmount, "Cvx Reward tokens are burnt");
        verifyReceiveERC20(tgUSD, usr2, borrowedAmount, "User 2, not the caller, receives tgUSD");

        hBorrow.borrow(usr2, borrowedAmount);

        assertERC20Tracking();

        assertEq(market.totalDebtShares(), borrowedAmount);
        assertEq(market.userDebtShares(usr1), borrowedAmount);
        assertEq(market.userDebtShares(usr2), 0);

        assertEq(market.userDebt(usr1), borrowedAmount);
        assertEq(market.userDebt(usr2), 0);

        assertEq(irCalculator.debtIndexes(address(market)), RAY, "Debt index didn't moove");

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));
        uint256 timeToPass = 900 days;
        uint256 expectedIRMintable = (ir * timeToPass * borrowedAmount) / 365 days / 1e18;
        skip(timeToPass);

        assertApproxEqAbs(market.pendingInterests(), expectedIRMintable, 1e18, "Interest mintable is correct");

        assertEq(market.userDebt(usr1), market.totalDebt(), "Position debt is the same as even after a some time passed");

        irCalculator.mintIR();

        assertEq(
            market.totalDebt(),
            (market.totalDebtShares() * irCalculator.debtIndexes(address(market))) / 1e27 + market.pendingInterests(),
            "Total debt is equal to the last total debt + pending interests"
        );
        assertEq(market.userDebt(usr1), market.totalDebt());

        uint256 maxRepayPartialAmount = market.userDebt(usr1) - minimumLoan;

        repayAmount = bound(repayAmount, 1, maxRepayPartialAmount);

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([owner]));
        tgUSD.mint(usr1, repayAmount);
        vm.stopPrank();

        hRepay.repay(usr1, repayAmount);

        assertEq(market.userDebt(usr1), market.totalDebt(), "Position debt is equal to total debt after a partial repay");

        skip(700 days);

        assertEq(market.userDebt(usr1), market.totalDebt());

        // vm.startPrank(owner);
        // tgUSD.mint(usr1, market.userDebt(usr1));
        // vm.stopPrank();

        // hRepay.repay(usr1, MAX_UINT, address(0));

        // assertEq(market.userDebt(usr1), market.totalDebt());

        // assertEq(0, market.userDebt(usr1), "User debt is 0 after a repay all");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract BorrowCvxMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    IRParams public irParams;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HRepay public hRepay;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        vm.startPrank(owner);

        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collatToken)];
        irParams = IRParams({isHEC: false, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 1_000_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
        market = ConvexCrvLPMarket(marketCreator.createConvexCrvMarket(getMarketInit(initP.marketInit, collatToken), initP.pid, irParams, getBaseRCParams()));
        vm.stopPrank();

        labeliser.labeliseNewConvexCrvMarket(address(collatToken), "crvUSD-USDC", address(market), address(market.cvxRewardToken()));

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
        hRepay = new HRepay(usr1, market, usg, marketViewer);

        minimumLoan = market.minimumLoan();
    }
    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer(true) * market.maxLTV());
    }

    function test_borrow_consistency() external {
        uint256 collatDeposited = 100_000 ether;
        uint256 borrowedAmount1 = 60_000 ether;
        uint256 borrowedAmount2 = 10_000 ether;
        uint256 repayAmount1 = 50_000 ether;
        uint256 repayAmount2 = 50_000 ether;
        deal(address(collatToken), usr1, collatDeposited);

        hDeposit.deposit(usr1, collatDeposited, true);
        hBorrow.borrow(usr1, borrowedAmount1);
        // assertEq(market.positionDebt(usr1), market.totalDebt());
        // assertEq(market.positionDebt(usr1), borrowedAmount1);
        skip(365 days);
        // assertEq(market.positionDebt(usr1), market.totalDebt());
        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));

        uint256 positionDebt1 = borrowedAmount1 + marketViewer.pendingInterests(market);
        assertApproxEqAbs(marketViewer.userDebt(market, usr1), positionDebt1, 2, "Position debt increased with interest rateaa");
        hBorrow.borrow(usr1, borrowedAmount2);
        // assertEq(market.positionDebt(usr1), market.totalDebt());
        // assertEq(market.userDebtShares(usr1), market.totalDebtShares());
        assertApproxEqAbs(marketViewer.userDebt(market, usr1), positionDebt1 + borrowedAmount2, 1, "Position debt increased with interest rate"); // 62400 + 10000 = 72400

        (ir, ) = irCalculator.irCheckpoints(address(market));
        skip(365 days);
        uint256 interestGeneratedExpected2 = marketViewer.pendingInterests(market);
        // console.log(interestGeneratedExpected2)
        assertApproxEqAbs(marketViewer.totalDebt(market), positionDebt1 + borrowedAmount2 + interestGeneratedExpected2, 5, "Pouloulou"); // 72400 + 72400*0.04 = 75296
        assertEq(marketViewer.userDebt(market, usr1), marketViewer.totalDebt(market));
    }

    function test_borrow(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan + 1, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        deal(address(collatToken), usr1, collatDeposited);

        hDeposit.deposit(usr1, collatDeposited, false);

        verifyMintERC20(usg, borrowedAmount, "Cvx Reward tokens are burnt");
        verifyReceiveERC20(usg, usr2, borrowedAmount, "User 2, not the caller, receives USG");

        hBorrow.borrow(usr2, borrowedAmount);

        assertERC20Tracking();

        assertEq(market.totalDebtShares(), borrowedAmount);
        assertEq(market.userDebtShares(usr1), borrowedAmount);
        assertEq(market.userDebtShares(usr2), 0);

        assertEq(marketViewer.userDebt(market, usr1), borrowedAmount);
        assertEq(marketViewer.userDebt(market, usr2), 0);

        assertEq(irCalculator.debtIndexes(address(market)), RAY, "Debt index didn't moove");

        uint256 timeToPass = 900 days;
        skip(timeToPass);

        assertApproxEqAbs(marketViewer.userDebt(market, usr1), marketViewer.totalDebt(market), 4, "Position debt is the same as even after a some time passed");
        irCalculator.mintIR();

        uint256 maxRepayPartialAmount = marketViewer.userDebt(market, usr1) - minimumLoan;

        repayAmount = bound(repayAmount, 1, maxRepayPartialAmount);

        vm.startPrank(owner);
        controlTower.toggleMarket(owner);
        usg.mint(usr1, repayAmount);
        vm.stopPrank();

        hRepay.repay(usr1, repayAmount);

        assertEq(marketViewer.userDebt(market, usr1), marketViewer.totalDebt(market), "Position debt is equal to total debt after a partial repay");

        skip(700 days);

        assertEq(marketViewer.userDebt(market, usr1), marketViewer.totalDebt(market));

        vm.startPrank(owner);
        usg.mint(usr1, marketViewer.userDebt(market, usr1));
        vm.stopPrank();

        hRepay.repay(usr1, MAX_UINT);

        assertEq(marketViewer.userDebt(market, usr1), marketViewer.totalDebt(market));

        assertEq(0, marketViewer.userDebt(market, usr1), "User debt is 0 after a repay all");
    }
}

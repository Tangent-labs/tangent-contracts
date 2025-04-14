// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/BorrowRepay/HRepay.sol";
import "../../handler/Features/HProcessRewards.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract BorrowCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    HRepay public hRepay;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hRepay = new HRepay(usr1, market);

        minimumLoan = market.minimumLoan();
    }
    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * market.maxLTV());
    }

    function test_borrow_consistency() external {
        uint256 collatDeposited = 100_000 ether;
        uint256 borrowedAmount1 = 60_000 ether;
        uint256 borrowedAmount2 = 10_000 ether;

        hDeposit.deposit(usr1, collatDeposited, true);

        hBorrow.borrow(usr1, borrowedAmount1);

        assertEq(market.positionDebt(usr1), market.totalDebt());
        assertEq(market.positionDebt(usr1), borrowedAmount1);

        skip(365 days);
        assertEq(market.positionDebt(usr1), market.totalDebt());

        (uint256 ir, uint256 timestamp) = IIRCalculator(irCalculator).irCheckpoint(address(market));

        uint256 interestGenerated = (borrowedAmount1 * ir) / 1e18;

        uint256 positionDebt1 = borrowedAmount1 + interestGenerated; // 60 000 + 60 000 * 0.04 =60 000 + 2 400 = 62 400
        assertEq(market.positionDebt(usr1), borrowedAmount1 + interestGenerated, "Position debt increased with interest rate");

        hBorrow.borrow(usr1, borrowedAmount2);

        assertEq(market.positionDebt(usr1), market.totalDebt());
        assertEq(market.userDebtShares(usr1), market.totalDebtShares());
        assertApproxEqAbs(market.positionDebt(usr1), positionDebt1 + borrowedAmount2, 1, "Position debt increased with interest rate"); // 62400 + 10000 = 72400

        (ir, timestamp) = IIRCalculator(irCalculator).irCheckpoint(address(market));

        uint256 interestGeneratedExpected2 = ((positionDebt1 + borrowedAmount2) * ir) / 1e18;
        skip(365 days);

        // market.checkpointIR();

        assertEq(market.positionDebt(usr1), market.totalDebt());

        // Interests must be equals to the totalDebt minus what has been deposited
        assertEq(tgUSD.mintableInterests() + market.pendingInterests(), market.totalDebt() - borrowedAmount1 - borrowedAmount2);
    }

    function test_borrow_fuzzing(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
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

        assertEq(market.positionDebt(usr1), borrowedAmount);
        assertEq(market.positionDebt(usr2), 0);

        assertEq(market.debtIndex(), 1e18, "Debt index didn't moove");

        (uint256 ir, uint256 timestamp) = IIRCalculator(irCalculator).irCheckpoint(address(market));
        uint256 timeToPass = 900 days;
        uint256 expectedIRMintable = (ir * timeToPass * borrowedAmount) / 365 days / 1e18;
        skip(timeToPass);

        assertApproxEqAbs(market.pendingInterests(), expectedIRMintable, 1e18, "Interest mintable is correct");

        assertEq(market.positionDebt(usr1), market.totalDebt(), "Position debt is the same as even after a some time passed");

        tgUSD.mintIR();

        assertEq(
            market.totalDebt(),
            (market.totalDebtShares() * market.debtIndex()) / 1e18 + market.pendingInterests(),
            "Total debt is equal to the last total debt + pending interests"
        );
        assertEq(market.positionDebt(usr1), market.totalDebt());

        uint256 maxRepayPartialAmount = market.positionDebt(usr1) - minimumLoan;

        repayAmount = bound(repayAmount, 1, maxRepayPartialAmount);

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([owner]));
        tgUSD.mint(usr1, repayAmount);
        vm.stopPrank();

        hRepay.repay(usr1, repayAmount, address(0));

        assertEq(market.positionDebt(usr1), market.totalDebt(), "Position debt is equal to total debt after a partial repay");

        skip(700 days);

        assertEq(market.positionDebt(usr1), market.totalDebt());

        // vm.startPrank(owner);
        // tgUSD.mint(usr1, market.positionDebt(usr1));
        // vm.stopPrank();

        // hRepay.repay(usr1, MAX_UINT, address(0));

        // assertEq(market.positionDebt(usr1), market.totalDebt());

        // assertEq(0, market.positionDebt(usr1), "User debt is 0 after a repay all");
    }
}

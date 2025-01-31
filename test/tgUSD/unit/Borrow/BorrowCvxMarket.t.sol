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
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * 85_000);
    }

    function test_borrow(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan + 1, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited, true);

        verifyMintERC20(tgUSD, borrowedAmount, "Cvx Reward tokens are burnt");
        verifyReceiveERC20(tgUSD, usr2, borrowedAmount, "User 2, not the caller, receives tgUSD");

        hBorrow.borrow(usr2, borrowedAmount);

        assertERC20Tracking();

        assertEq(market.lastDebt(), borrowedAmount);
        assertEq(market.positionDebtIndex(usr1), borrowedAmount);
        assertEq(market.positionDebtIndex(usr2), 0);

        assertEq(market.positionDebt(usr1), borrowedAmount);
        assertEq(market.positionDebt(usr2), 0);

        assertEq(market.debtIndex(), 10 ** 18, "Debt index didn't moove");

        skip(15 days);

        assertEq(market.positionDebt(usr1), market.totalDebt());

        tgUSD.mintIR();

        assertEq(market.totalDebt(), market.lastDebt() + market.pendingInterests());
        assertEq(market.positionDebt(usr1), market.totalDebt());

        uint256 maxRepayPartialAmount = market.positionDebt(usr1) - minimumLoan;

        repayAmount = bound(repayAmount, 1, maxRepayPartialAmount);

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([owner]));
        tgUSD.mint(usr1, repayAmount);
        vm.stopPrank();

        hRepay.repay(usr1, repayAmount, address(0));

        skip(30);

        vm.startPrank(owner);
        tgUSD.mint(usr1, market.positionDebt(usr1));
        vm.stopPrank();

        hRepay.repay(usr1, MAX_UINT, address(0));

        // assertEq(0, market.positionDebt(usr1), "User debt is 0 after a repay all");
    }
}

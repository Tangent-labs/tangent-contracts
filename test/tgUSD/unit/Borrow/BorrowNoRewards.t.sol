// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/BorrowRepay/HRepay.sol";

contract BorrowNoRewards is ConvexCurveContext {
    MarketNoRewards public market;
    IERC20Metadata public collatToken;

    HDepositNoRewards public hDeposit;
    HBorrow public hBorrow;
    HRepay public hRepay;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrERC4626.S_DAI;
        market = deployNoRewardsMarket(collatToken);

        hDeposit = new HDepositNoRewards(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hRepay = new HRepay(usr1, market);
        minimumLoan = market.minimumLoan();
    }
    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * 85_000);
    }

    function test_borrow(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, market.maxMarketDebt());

        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr2, collatDeposited, true);

        verifyMintERC20(tgUsd, borrowedAmount, "Cvx Reward tokens are burnt");
        verifyReceiveERC20(tgUsd, usr2, borrowedAmount, "User 2, not the caller, receives tgUSD");

        hBorrow.setMsgSender(usr2);
        hRepay.setMsgSender(usr2);
        hBorrow.borrow(usr2, borrowedAmount);

        assertERC20Tracking();

        assertEq(market.lastDebt(), borrowedAmount);
        assertEq(market.positionDebtIndex(usr1), 0);
        assertEq(market.positionDebtIndex(usr2), borrowedAmount);

        assertEq(market.positionDebt(usr1), 0);
        assertEq(market.positionDebt(usr2), borrowedAmount);

        assertEq(market.debtIndex(), 10 ** 27, "Debt index didn't moove");

        skip(15 days);

        assertEq(market.positionDebt(usr2), market.totalDebt());

        tgUsd.mintIR();

        assertEq(market.totalDebt(), market.lastDebt() + market.pendingInterests());
        assertEq(market.positionDebt(usr2), market.totalDebt());

        repayAmount = bound(repayAmount, 1, market.positionDebt(usr2) - market.minimumLoan());

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([owner]));
        tgUsd.mint(usr2, repayAmount);
        vm.stopPrank();

        hRepay.repay(usr2, repayAmount, address(0));

        skip(30);

        vm.startPrank(owner);
        tgUsd.mint(usr2, market.positionDebt(usr2));
        vm.stopPrank();

        // Repay all
        hRepay.repay(usr2, MAX_UINT, address(0));

        assertEq(0, market.positionDebt(usr2), "User debt is 0 after a repay all");
    }
}

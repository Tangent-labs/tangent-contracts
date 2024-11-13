import "../../contexts/ConvexCurveContext.sol";

contract BorrowCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public convexMarket;
    IERC20Metadata public collatToken;
    uint256 minimumLoan;
    function setUp() public {
        deployBaseContracts();
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        convexMarket = deployConvexCurveLPMarket(collatToken);
        minimumLoan = convexMarket.minimumLoan();
    }

    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (convexMarket.collatOracle().latestAnswer() * 85_000);
    }

    function test_borrow(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, convexMarket.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        vm.startPrank(usr1);
        AddrCurveStableLP.CRVUSD_USDC.approve(address(convexMarket), MAX_UINT);

        convexMarket.deposit(usr1, collatDeposited, true);

        verifyMintERC20(tgUsd, borrowedAmount, "Cvx Reward tokens are burnt");
        verifyReceiveERC20(tgUsd, usr2, borrowedAmount, "User 2, not the caller, receives tgUSD");

        vm.startSnapshotGas("Borrow", "First borrow on a init market");
        convexMarket.borrow(usr2, borrowedAmount);
        vm.stopSnapshotGas();

        assertERC20Tracking();

        assertEq(convexMarket.lastDebt(), borrowedAmount);
        assertEq(convexMarket.positionDebtIndex(usr1), borrowedAmount);
        assertEq(convexMarket.positionDebtIndex(usr2), 0);

        assertEq(convexMarket.positionDebt(usr1), borrowedAmount);
        assertEq(convexMarket.positionDebt(usr2), 0);

        assertEq(convexMarket.debtIndex(), 10 ** 27, "Debt index didn't moove");

        skip(15 days);

        assertEq(convexMarket.positionDebt(usr1), convexMarket.totalDebt());

        address[] memory markets = new address[](1);
        markets[0] = address(convexMarket);
        irMinter.mintIR(markets);

        assertEq(convexMarket.totalDebt(), convexMarket.lastDebt() + convexMarket.pendingInterests());
        assertEq(convexMarket.positionDebt(usr1), convexMarket.totalDebt());

        repayAmount = bound(repayAmount, 1, convexMarket.positionDebt(usr1) - convexMarket.minimumLoan());

        uint256 user1Debt = convexMarket.positionDebt(usr1);
        deal(address(tgUsd), usr1, repayAmount);
        convexMarket.repay(usr1, repayAmount);

        // assertEq(convexMarket.positionDebt(usr1), user1Debt - repayAmount);
    }
}

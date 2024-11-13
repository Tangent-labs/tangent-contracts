import "../../contexts/ConvexCurveContext.sol";

contract DepositAndBorrowCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public convexMarket;
    IERC20Metadata public collatToken;
    function setUp() public {
        deployBaseContracts();
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        convexMarket = deployConvexCurveLPMarket(collatToken);
    }

    //
    function test_deposit_and_borrow_stake() external {
        uint256 collatDeposited1 = 4_000 ether;
        uint256 borrowedAmount1 = 3_440 ether;
        vm.startPrank(usr1);
        AddrCurveStableLP.CRVUSD_USDC.approve(address(convexMarket), MAX_UINT);

        verifyReceiveERC20(convexMarket.cvxRewardToken(), address(convexMarket), collatDeposited1, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.CRVUSD_USDC, address(convexMarket), "Verify that as staking, no LP are received by the Market");
        verifyLostERC20(AddrCurveStableLP.CRVUSD_USDC, usr1, collatDeposited1, "Verify that user sent its LP");
        verifyMintERC20(tgUsd, borrowedAmount1, "tgUSD are not minted");
        verifyReceiveERC20(tgUsd, usr1, borrowedAmount1, "User receives the borrowed amount");

        vm.startSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");
        convexMarket.depositAndBorrow(collatDeposited1, borrowedAmount1, true);
        vm.stopSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");

        assertERC20Tracking();

        assertEq(convexMarket.collateralBalances(usr1), collatDeposited1, "Collateral deposited must be equal to collateralBalances");
        assertEq(convexMarket.totalCollateral(), collatDeposited1, "Total collateral is not right");
        assertEq(convexMarket.positionDebt(usr1), borrowedAmount1, "Position debt should be equal to the borrowed amount");
        assertEq(convexMarket.positionDebtIndex(usr1), borrowedAmount1, "Position debt index should be 0");
        assertEq(convexMarket.totalDebt(), borrowedAmount1, "Total debt should be 0");
        assertEq(convexMarket.socFeePending(), 0);

        skip(15 days);
        vm.stopPrank();

        vm.startPrank(usr2);

        uint256 collatDeposited2 = 8_000 ether;
        uint256 borrowedAmount2 = 6_000 ether;

        AddrCurveStableLP.CRVUSD_USDC.approve(address(convexMarket), MAX_UINT);

        verifyReceiveERC20(convexMarket.cvxRewardToken(), address(convexMarket), collatDeposited2, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.CRVUSD_USDC, address(convexMarket), "Verify that as staking, no LP are received by the Market");
        verifyLostERC20(AddrCurveStableLP.CRVUSD_USDC, usr2, collatDeposited2, "Verify that user sent its LP");
        verifyReceiveERC20(tgUsd, usr2, borrowedAmount2, "User receives 50 tgUSD");

        convexMarket.depositAndBorrow(collatDeposited2, borrowedAmount2, true);

        assertERC20Tracking();
        assertEq(convexMarket.collateralBalances(usr2), collatDeposited2, "Collateral deposited must be equal to collateralBalances");
        assertEq(convexMarket.totalCollateral(), collatDeposited1 + collatDeposited2, "Total collateral is not right");

        /// TODO See if it's possible to get closer
        assertApproxEqAbs(convexMarket.positionDebt(usr2), borrowedAmount2, 1, "Position debt displays the real debt for a user");

        /// TODO See if it's possible to get closer
        assertApproxEqAbs(convexMarket.totalDebt(), convexMarket.positionDebt(usr1) + convexMarket.positionDebt(usr2), 1, "Total Debt equals sum of all debt");

        assertEq(convexMarket.socFeePending(), 0);

        skip(1 days);
        vm.stopPrank();

        vm.startPrank(usr1);

        vm.startSnapshotGas("Deposit and Repay", "Deposit and repay on user already init, no stake");
        convexMarket.depositAndRepay(usr1, collatDeposited2, 440 ether, false);
        vm.stopSnapshotGas("Deposit and Repay", "Deposit and repay on user already init, no stake");
    }
}

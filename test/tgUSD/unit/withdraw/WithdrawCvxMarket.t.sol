import "../../contexts/ConvexCurveContext.sol";

contract WithdrawCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public convexMarket;
    IERC20Metadata public collatToken;
    function setUp() public {
        deployBaseContracts();
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        convexMarket = deployConvexCurveLPMarket(collatToken);
    }

    function test_withdraw_fully_from_staked() external {
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        convexMarket.depositAndBorrow(amountIn, borrowedAmount, true);

        uint256 withdrawnAmount = 1_000 ether;

        verifyLostERC20(convexMarket.cvxRewardToken(), address(convexMarket), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        verifyBurnERC20(convexMarket.cvxRewardToken(), withdrawnAmount, "Verify that Cvx Reward tokens are burnt");
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        convexMarket.withdraw(withdrawnAmount);
        vm.stopSnapshotGas();

        assertERC20Tracking();
    }

    function test_withdraw_fully_from_not_staked() external {
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        convexMarket.depositAndBorrow(amountIn, borrowedAmount, false);

        uint256 withdrawnAmount = 1_000 ether;

        verifyLostERC20(collatToken, address(convexMarket), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw fully from unstaked collat");
        convexMarket.withdraw(withdrawnAmount);
        vm.stopSnapshotGas();

        assertERC20Tracking();

        assertEq(convexMarket.collateralBalances(usr1), amountIn - withdrawnAmount - convexMarket.socFeePending());
    }

    function test_withdraw_from_staked_and_not_staked() external {
        uint256 amountInStaked = 10_000 ether;
        uint256 borrowedAmount1 = 5_000 ether;
        uint256 borrowedAmount2 = 1_000 ether;

        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        convexMarket.depositAndBorrow(amountInStaked, borrowedAmount1, true);
        convexMarket.depositAndBorrow(amountInStaked, borrowedAmount2, false);

        uint256 withdrawnAmount = 12_000 ether;
        uint256 availableAmount = convexMarket.collatToken().balanceOf(address(convexMarket)) - convexMarket.socFeePending();
        uint256 amountWithdrawnFromConvex = withdrawnAmount - availableAmount;
        uint256 amountWithdrawnDirectly = withdrawnAmount - amountWithdrawnFromConvex;
        verifyLostERC20(
            convexMarket.cvxRewardToken(),
            address(convexMarket),
            amountWithdrawnFromConvex,
            "Verify that we withdraw the right amount of Cvx Reward"
        );
        verifyBurnERC20(convexMarket.cvxRewardToken(), amountWithdrawnFromConvex, "Verify that Cvx Reward tokens are burnt");

        verifyLostERC20(
            collatToken,
            address(convexMarket),
            amountWithdrawnDirectly,
            "Verify that we withdraw the right amount of LP unstaked Cvx Reward tokens"
        );
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        vm.startSnapshotGas("Withdraw", "Withdraw from staked and unstaked collat");
        convexMarket.withdraw(withdrawnAmount);
        vm.stopSnapshotGas();

        assertERC20Tracking();

        assertEq(convexMarket.collateralBalances(usr1), 2 * amountInStaked - withdrawnAmount - convexMarket.socFeePending());
    }
}

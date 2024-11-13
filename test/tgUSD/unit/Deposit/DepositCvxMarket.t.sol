import "../../contexts/ConvexCurveContext.sol";

contract DepositCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public convexMarket;
    IERC20Metadata public collatToken;
    function setUp() public {
        deployBaseContracts();
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        convexMarket = deployConvexCurveLPMarket(collatToken);
    }

    //
    function test_deposit_stake() external {
        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        verifyReceiveERC20(convexMarket.cvxRewardToken(), address(convexMarket), 100 ether, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(collatToken, address(convexMarket), "Verify that as staking, no LP are received by the Market");

        verifyLostERC20(collatToken, usr1, 100 ether, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and stake");
        convexMarket.deposit(usr1, 100 ether, true);
        vm.stopSnapshotGas();
        skip(100);

        assertERC20Tracking();

        assertEq(convexMarket.collateralBalances(usr1), 100 ether, "Collateral deposited must be equal to collateralBalances");
        assertEq(convexMarket.totalCollateral(), 100 ether, "Total collateral is not right");

        assertEq(convexMarket.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(convexMarket.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(convexMarket.totalDebt(), 0, "Total debt should be 0");

        assertEq(convexMarket.healthRatio(usr1), MAX_UINT);
        assertEq(convexMarket.liquidationPrice(usr1), 0);
        assertEq(convexMarket.socFeePending(), 0);

        vm.startSnapshotGas("Deposit", "Second user deposit and stake");
        convexMarket.deposit(usr1, 100 ether, true);
        vm.stopSnapshotGas();
    }

    function test_deposit_no_stake() external {
        uint256 amountIn = 100 ether;
        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        uint256 feeToTake = (amountIn * convexMarket.socFeePercentage()) / 100_000;
        uint256 amountStaked = amountIn - feeToTake;

        verifyBalERC20NotChanging(convexMarket.cvxRewardToken(), address(convexMarket), "Verify that as not staking, no Cvx rewards are received");

        verifyReceiveERC20(collatToken, address(convexMarket), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and no stake");
        convexMarket.deposit(usr1, amountIn, false);
        vm.stopSnapshotGas("Deposit", "First deposit ever on the market and no stake");

        skip(100);
        assertERC20Tracking();

        assertEq(convexMarket.totalCollateral(), amountStaked, "Total collateral is not right");
        assertEq(convexMarket.collateralBalances(usr1), amountStaked, "Collateral deposited must be equal to collateralBalances");

        assertEq(convexMarket.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(convexMarket.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(convexMarket.totalDebt(), 0, "Total debt should be 0");

        assertEq(convexMarket.healthRatio(usr1), MAX_UINT);
        assertEq(convexMarket.liquidationPrice(usr1), 0);
        assertEq(convexMarket.socFeePending(), feeToTake);

        vm.startSnapshotGas("Deposit", "Second user deposit and no stake");
        convexMarket.deposit(usr1, amountIn, false);
        vm.stopSnapshotGas("Deposit", "Second user deposit and no stake");
    }

    function test_deposit_no_stake_then_stake() external {
        uint256 amountIn = 100 ether;

        vm.startPrank(usr1);
        collatToken.approve(address(convexMarket), MAX_UINT);

        convexMarket.deposit(usr1, amountIn, true);

        uint256 feeToTake = (amountIn * convexMarket.socFeePercentage()) / 100_000;
        uint256 amountStaked = amountIn - feeToTake;

        verifyBalERC20NotChanging(convexMarket.cvxRewardToken(), address(convexMarket), "Verify that as not staking, no Cvx rewards are received");
        verifyReceiveERC20(collatToken, address(convexMarket), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        convexMarket.deposit(usr1, amountIn, false);

        assertERC20Tracking();

        assertEq(convexMarket.totalCollateral(), amountStaked + amountIn, "Total collateral is not right");
        assertEq(convexMarket.collateralBalances(usr1), amountStaked + amountIn, "Collateral deposited must be equal to collateralBalances");

        assertEq(convexMarket.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(convexMarket.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(convexMarket.totalDebt(), 0, "Total debt should be 0");

        assertEq(convexMarket.healthRatio(usr1), MAX_UINT);
        assertEq(convexMarket.liquidationPrice(usr1), 0);
        assertEq(convexMarket.socFeePending(), feeToTake);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEPOSIT WITHOUT STAKE GET SOC FEES
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        verifyBalERC20NotChanging(convexMarket.cvxRewardToken(), address(convexMarket), "Verify that as not staking, no Cvx rewards are received");
        verifyReceiveERC20(collatToken, address(convexMarket), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
        convexMarket.deposit(usr1, amountIn, true);
        vm.stopSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
    }
}

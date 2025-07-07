// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract DepositCvxCrvMarket is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;

    uint256 amountIn = 100 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken, true);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
    }

    function test_deposit_stake() external {
        verifyReceiveERC20(market.cvxRewardToken(), address(market), 100 ether, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(collatToken, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(collatToken, usr1, 100 ether, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and stake");
        hDeposit.deposit(usr1, 100 ether);
        vm.stopSnapshotGas();

        skip(100);

        assertEq(market.collateralBalances(usr1), 100 ether, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), 100 ether, "Total collateral is not right");

        assertEq(market.userDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.userDebtShares(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);
        assertEq(market.socFeePending(), 0);

        vm.startSnapshotGas("Deposit", "Second user deposit and stake");
        hDeposit.deposit(usr1, 100 ether);
        vm.stopSnapshotGas();
    }

    function test_deposit_no_stake() external {
        verifyBalERC20NotChanging(market.cvxRewardToken(), address(market), "Verify that as not staking, no Cvx rewards are received");

        verifyReceiveERC20(collatToken, address(market), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and no stake");
        hDeposit.deposit(usr1, amountIn);
        vm.stopSnapshotGas("Deposit", "First deposit ever on the market and no stake");

        assertERC20Tracking();

        skip(100);

        assertEq(market.totalCollateral(), amountIn, "Total collateral is not right");
        assertEq(market.collateralBalances(usr1), amountIn, "Collateral deposited must be equal to collateralBalances");

        assertEq(market.userDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.userDebtShares(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);

        vm.startSnapshotGas("Deposit", "Second user deposit and no stake");
        hDeposit.deposit(usr1, amountIn);
        vm.stopSnapshotGas("Deposit", "Second user deposit and no stake");
    }

    function test_deposit_no_stake_then_stake() external {
        vm.startPrank(usr1);

        hDeposit.deposit(usr1, amountIn);

        verifyBalERC20NotChanging(market.cvxRewardToken(), address(market), "Verify that as not staking, no Cvx rewards are received");
        verifyReceiveERC20(collatToken, address(market), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        hDeposit.deposit(usr1, amountIn);
        assertERC20Tracking();

        assertEq(market.totalCollateral(), amountIn + amountIn, "Total collateral is not right");
        assertEq(market.collateralBalances(usr1), amountIn + amountIn, "Collateral deposited must be equal to collateralBalances");

        assertEq(market.userDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.userDebtShares(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEPOSIT WITHOUT STAKE GET SOC FEES
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
        hDeposit.deposit(usr1, amountIn);
        vm.stopSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
    }
}

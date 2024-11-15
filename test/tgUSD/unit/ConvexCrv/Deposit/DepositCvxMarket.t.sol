// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

contract DepositCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
    }

    //
    function test_deposit_stake() external {
        verifyReceiveERC20(market.cvxRewardToken(), address(market), 100 ether, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(collatToken, address(market), "Verify that as staking, no LP are received by the Market");
        verifyLostERC20(collatToken, usr1, 100 ether, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and stake");
        hDeposit.deposit(usr1, 100 ether, true);
        vm.stopSnapshotGas();

        skip(100);

        assertEq(market.collateralBalances(usr1), 100 ether, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), 100 ether, "Total collateral is not right");

        assertEq(market.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);
        assertEq(market.socFeePending(), 0);

        vm.startSnapshotGas("Deposit", "Second user deposit and stake");
        hDeposit.deposit(usr1, 100 ether, true);
        vm.stopSnapshotGas();
    }

    function test_deposit_no_stake() external {
        uint256 amountIn = 100 ether;

        collatToken.approve(address(market), MAX_UINT);

        uint256 feeToTake = (amountIn * market.socFeePercentage()) / 100_000;
        uint256 amountStaked = amountIn - feeToTake;

        verifyBalERC20NotChanging(market.cvxRewardToken(), address(market), "Verify that as not staking, no Cvx rewards are received");

        verifyReceiveERC20(collatToken, address(market), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and no stake");
        hDeposit.deposit(usr1, amountIn, false);
        vm.stopSnapshotGas("Deposit", "First deposit ever on the market and no stake");

        skip(100);

        assertEq(market.totalCollateral(), amountStaked, "Total collateral is not right");
        assertEq(market.collateralBalances(usr1), amountStaked, "Collateral deposited must be equal to collateralBalances");

        assertEq(market.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);
        assertEq(market.socFeePending(), feeToTake);

        vm.startSnapshotGas("Deposit", "Second user deposit and no stake");
        hDeposit.deposit(usr1, amountIn, false);
        vm.stopSnapshotGas("Deposit", "Second user deposit and no stake");
    }

    function test_deposit_no_stake_then_stake() external {
        uint256 amountIn = 100 ether;

        vm.startPrank(usr1);

        hDeposit.deposit(usr1, amountIn, true);

        uint256 feeToTake = (amountIn * market.socFeePercentage()) / 100_000;
        uint256 amountStaked = amountIn - feeToTake;

        verifyBalERC20NotChanging(market.cvxRewardToken(), address(market), "Verify that as not staking, no Cvx rewards are received");
        verifyReceiveERC20(collatToken, address(market), amountIn, "Verify that market receives Cvx Reward tokens");
        verifyLostERC20(collatToken, usr1, amountIn, "Verify that user sent its LP");

        hDeposit.deposit(usr1, amountIn, false);

        assertEq(market.totalCollateral(), amountStaked + amountIn, "Total collateral is not right");
        assertEq(market.collateralBalances(usr1), amountStaked + amountIn, "Collateral deposited must be equal to collateralBalances");

        assertEq(market.positionDebt(usr1), 0, "Position debt should be 0");
        assertEq(market.positionDebtIndex(usr1), 0, "Position debt index should be 0");
        assertEq(market.totalDebt(), 0, "Total debt should be 0");

        assertEq(market.healthRatio(usr1), MAX_UINT);
        assertEq(market.liquidationPrice(usr1), 0);
        assertEq(market.socFeePending(), feeToTake);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEPOSIT WITHOUT STAKE GET SOC FEES
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
        hDeposit.deposit(usr1, amountIn, true);
        vm.stopSnapshotGas("Deposit", "Second user deposit, stakes and takes pendingFees");
    }
}

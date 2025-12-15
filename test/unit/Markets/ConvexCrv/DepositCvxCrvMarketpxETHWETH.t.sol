// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract DepositCvxCrvMarketpxETHWETH is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;

    uint256 amountIn = 100 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.WETH_frxETH;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
    }

    function test_market_deposit() external {
        deal(address(collatToken), address(usr1), 100 ether);

        vm.startPrank(usr1);
        collatToken.approve(address(market), 50 ether);
        vm.startSnapshotGas("Deposit", "First deposit ever on the market and stake");
        market.deposit(address(usr1), 50 ether, false);
        vm.stopPrank();
        vm.stopSnapshotGas();
    }

    function test_deposit_stake() external {
        verifyReceiveERC20(market.cvxRewardToken(), address(market), 100 ether, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(collatToken, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(collatToken, usr1, 100 ether, "Verify that user sent its LP");

        vm.startSnapshotGas("Deposit", "First deposit ever on the market and stake");
        hDeposit.deposit(usr1, 100 ether, false);
        vm.stopSnapshotGas();

        skip(100);

        assertEq(market.collateralBalances(usr1), 100 ether, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), 100 ether, "Total collateral is not right");

        assertEq(marketViewer.userDebt(market, usr1), 0, "Position debt should be 0");
        assertEq(market.userDebtShares(usr1), 0, "Position debt index should be 0");
        assertEq(marketViewer.totalDebt(market), 0, "Total debt should be 0");

        assertEq(marketViewer.healthRatio(address(market), usr1), MAX_UINT);

        vm.startSnapshotGas("Deposit", "Second user deposit and stake");
        hDeposit.deposit(usr1, 100 ether, false);
        vm.stopSnapshotGas();
    }
}

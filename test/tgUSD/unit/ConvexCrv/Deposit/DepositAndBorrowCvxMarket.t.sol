// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract DepositAndBorrowCvxMarket is ConvexCurveContext {
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
    function test_deposit_and_borrow_stake() external {
        uint256 collatDeposited1 = 5_000 ether;
        uint256 borrowedAmount1 = 3_440 ether;

        verifyReceiveERC20(market.cvxRewardToken(), address(market), collatDeposited1, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.CRVUSD_USDC, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(AddrCurveStableLP.CRVUSD_USDC, usr1, collatDeposited1, "Verify that user sent its LP");
        verifyMintERC20(tgUSD, borrowedAmount1, "tgUSD are not minted");
        verifyReceiveERC20(tgUSD, usr1, borrowedAmount1, "User receives the borrowed amount");

        vm.startSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");
        hDeposit.depositAndBorrow(collatDeposited1, borrowedAmount1, true, address(0));
        vm.stopSnapshotGas("Deposit And Borrow", "First deposit and borrow ever on the market and stake");

        assertEq(market.collateralBalances(usr1), collatDeposited1, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), collatDeposited1, "Total collateral is not right");
        assertEq(market.positionDebt(usr1), borrowedAmount1, "Position debt should be equal to the borrowed amount");
        assertEq(market.positionDebtIndex(usr1), borrowedAmount1, "Position debt index should be 0");
        assertEq(market.totalDebt(), borrowedAmount1, "Total debt should be 0");
        assertEq(market.socFeePending(), 0);

        skip(15 days);

        uint256 collatDeposited2 = 8_000 ether;
        uint256 borrowedAmount2 = 6_000 ether;

        verifyReceiveERC20(market.cvxRewardToken(), address(market), collatDeposited2, "Verify that market receives Cvx Reward tokens");
        verifyBalERC20NotChanging(AddrCurveStableLP.CRVUSD_USDC, address(market), "Verify that as staking, no LP are received by the MarketCore");
        verifyLostERC20(AddrCurveStableLP.CRVUSD_USDC, usr2, collatDeposited2, "Verify that user sent its LP");
        verifyReceiveERC20(tgUSD, usr2, borrowedAmount2 + 12, "User receives 50 tgUSD");

        hDeposit.setMsgSender(usr2);
        hDeposit.depositAndBorrow(collatDeposited2, borrowedAmount2, true, address(0));

        assertEq(market.collateralBalances(usr2), collatDeposited2, "Collateral deposited must be equal to collateralBalances");
        assertEq(market.totalCollateral(), collatDeposited1 + collatDeposited2, "Total collateral is not right");

        // TODO See if it's possible to get closer
        assertApproxEqAbs(market.positionDebt(usr2), borrowedAmount2, 1, "Position debt displays the real debt for a user");

        // TODO See if it's possible to get closer
        assertEq(market.totalDebt(), market.positionDebt(usr1) + market.positionDebt(usr2), "Total Debt equals sum of all debt");

        assertEq(market.socFeePending(), 0);

        skip(1 days);
    }
}

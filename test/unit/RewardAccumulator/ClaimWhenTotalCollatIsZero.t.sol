// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/HProcessRewards.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract ClaimWhenTotalCollatIsZero is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken, true);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
    }

    //
    function test_claim_exploit() external {
        uint256 collatDeposited1 = 5_000 ether;
        uint256 borrowedAmount1 = 3_440 ether;

        hDeposit.depositAndBorrow(collatDeposited1, borrowedAmount1);
        skip(7 days);

        vm.startPrank(usr1);
        rewardAccumulator.processRewards(address(market), usr1);
        skip(7 days);

        // Total collateral becomes 0
        market.repayAndWithdraw(collatDeposited1, MAX_UINT);
        vm.stopPrank();

        vm.startPrank(usr2);

        hDeposit.setMsgSender(usr2);

        hDeposit.deposit(usr2, 5_000 ether);
        skip(7 days);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = AddrClassicERC20.CRV;
        tokens[1] = AddrClassicERC20.CVX;
        // User 2 has nothing to claim because nothing has been process to him yet
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardToSimpleClaim.selector));
        rewardAccumulator.claimSimple(address(market));
        rewardAccumulator.claimCutFees(tokens);

        vm.stopPrank();
        vm.prank(usr1);
        rewardAccumulator.claimSimple(address(market));

        // We expect that there is almost nothing at all on the RewardAccumulator because everything has been streamed, fees are claimed

        assertApproxEqAbs(AddrClassicERC20.CRV.balanceOf(address(rewardAccumulator)), 0, 300_000);
        assertApproxEqAbs(AddrClassicERC20.CVX.balanceOf(address(rewardAccumulator)), 0, 300_000);
    }
}

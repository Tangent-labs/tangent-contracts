// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract AddConvexLinkLater is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 amountIn = 10_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken, false);
    }

    function test_add_convex_link_later_and_verify_everything_is_fine() external {
        assertEq(address(0), address(market.cvxRewardToken()));
        assertEq(0, market.pid());

        deal(address(collatToken), usr1, 4 * amountIn);
        deal(address(collatToken), usr2, 4 * amountIn);

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        market.deposit(usr1, amountIn);
        vm.stopPrank();

        vm.startPrank(usr2);
        collatToken.approve(address(market), MAX_UINT);
        market.deposit(usr2, amountIn);
        vm.stopPrank();

        assertEq(0, market.socFeePending());

        vm.startPrank(owner);
        market.setConvexStaking(AddrCvxRewardTokens.USDC_crvUSD_LP, PidCvxCrvBooster.USDC_crvUSD_LP);

        assertEq(address(AddrCvxRewardTokens.USDC_crvUSD_LP), address(market.cvxRewardToken()));
        assertEq(PidCvxCrvBooster.USDC_crvUSD_LP, market.pid());

        vm.expectRevert(abi.encodeWithSelector(ConvexCrvLPMarket.CvxRewardTokenNull.selector, usr1));
        market.setConvexStaking(ICvxRewardToken(address(0)), 12);

        vm.expectRevert(abi.encodeWithSelector(ConvexCrvLPMarket.PidNull.selector, usr1));
        market.setConvexStaking(AddrCvxRewardTokens.USDC_crvUSD_LP, 0);
        IERC20[] memory rewards = new IERC20[](2);
        rewards[0] = AddrClassicERC20.CRV;
        rewards[1] = AddrClassicERC20.CVX;

        vm.stopPrank();

        vm.startPrank(usr1);
        market.deposit(usr1, amountIn);
        vm.stopPrank();

        vm.startPrank(usr2);
        market.deposit(usr2, amountIn);
        vm.stopPrank();

        vm.prank(owner);
        rewardAccumulator.addNewRewards(address(market), rewards);

        market.stakeAll(usr1);

        skip(7 days);

        rewardAccumulator.processRewards(address(market), usr1);

        skip(7 days);

        vm.prank(usr1);
        rewardAccumulator.claimSimple(address(market));

        vm.prank(usr2);
        rewardAccumulator.claimSimple(address(market));
    }
}

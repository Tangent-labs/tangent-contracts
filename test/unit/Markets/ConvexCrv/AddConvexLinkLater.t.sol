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

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, amountIn);
        market.deposit(usr1, amountIn, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr2, amountIn);
        market.deposit(usr2, amountIn, true);
        vm.stopPrank();

        vm.prank(owner);
        market.setConvexStaking(AddrCvxRewardTokens.USDC_crvUSD_LP, PidCvxCrvBooster.USDC_crvUSD_LP);

        assertEq(address(AddrCvxRewardTokens.USDC_crvUSD_LP), address(market.cvxRewardToken()));
        assertEq(PidCvxCrvBooster.USDC_crvUSD_LP, market.pid());
    }
}

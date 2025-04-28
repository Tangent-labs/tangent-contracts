// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";

contract LeverageToTheLimit is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;

    IStakingProxyERC20 stakingProxy;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        minimumLoan = market.minimumLoan();

        stakingProxy = market.stakingProxyVault();
    }

    function test_leverage_without_deposit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 0;
        uint256 tgUSDToFlashMint = 10_000 ether;
        uint256 minCollatOut = 9_995 ether;

        // We put some collat in pending on the zapping for mocking
        deal(address(collatToken), address(zappingProxy), minCollatOut);

        // Revert beaucause LTV is too low
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            minCollatOut,
            true,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), minCollatOut)})
        );
    }

    function test_leverage_to_limit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 tgUSDToFlashMint = 20_000 ether;
        uint256 collatReceived = 19_000 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER_V2), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector));

        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, collatToDeposit);

        // We put some collat in pending on the zapping for mocking
        deal(address(collatToken), address(zappingProxy), collatReceived);

        verifyMintERC20(tgUSD, tgUSDToFlashMint, "Some tgUSD are minted during leverage");

        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            collatReceived,
            true,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), collatReceived)})
        );

        assertEq(IERC20(stakingProxy.gaugeAddress()).balanceOf(address(stakingProxy)), collatReceived + collatToDeposit, "Convex staking proxy received Fxn Gauge");
        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertEq(market.userDebt(usr1), tgUSDToFlashMint);

        assertERC20Tracking();

        skip(7 days);

        rewardAccumulator.processRewards(address(market), usr2);

        skip(7 days);

        rewardAccumulator.claimSimple(address(market));

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardToSimpleClaim.selector));
        rewardAccumulator.claimSimple(address(market));
    }
}

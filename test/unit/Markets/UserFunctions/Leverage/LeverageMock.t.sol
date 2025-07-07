// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
contract LeverageMock is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;

    IStakingProxyERC20 stakingProxy;

    HLPManipulator hLpManipulator;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        minimumLoan = market.minimumLoan();

        stakingProxy = market.stakingProxyVault();

        hLpManipulator = new HLPManipulator(usr2);

        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 1, 0, 400_000 ether);
        skip(30 minutes);
        irCalculator.checkpointIR(address(market));
        skip(500 days);
    }

    function test_leverage_without_deposit_fails() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 0;
        uint256 USGToFlashMint = 10_000 ether;
        uint256 minCollatOut = 9_995 ether;

        // We put some collat in pending on the zapping for mocking
        deal(address(collatToken), address(zappingProxy), minCollatOut);

        // Revert beaucause LTV is too low
        vm.expectRevert(abi.encodeWithSelector(MarketCore.UserDebtTooHigh.selector));
        market.leverage(
            collatToDeposit,
            USGToFlashMint,
            minCollatOut,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), minCollatOut)})
        );
    }

    function test_leverage_without_staking() external {
        vm.startPrank(usr3);
        uint256 collatToDeposit = 100_000 ether;
        uint256 USGToFlashMint = 200_000 ether;
        uint256 collatReceived = 190_000 ether;

        uint256 totalCollat = collatToDeposit + collatReceived;

        // Prepare user
        collatToken.approve(address(market), MAX_UINT);
        // Put some collat on the mocked router, ready to be sent back to the market
        deal(address(collatToken), address(mockRouter), collatReceived);

        verifyMintERC20(usg, USGToFlashMint, "Some USG are minted during leverage");
        verifyReceiveERC20(usg, address(mockRouter), USGToFlashMint, "USG are sent to the router");

        verifyLostERC20(collatToken, usr3, collatToDeposit, "Collat token taken from usr1");
        verifyReceiveERC20(collatToken, address(market), collatToDeposit + collatReceived, "Collat token received by the market, removing soc Fee");

        market.leverage(
            collatToDeposit,
            USGToFlashMint,
            collatReceived,
            // Simulate zap call with a transfer to the market
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, USGToFlashMint, collatToken, address(market), collatReceived)
        );
        uint256 index = irCalculator.debtIndexes(address(market));

        assertEq(market.collateralBalances(usr3), expectedStaked);
        assertEq(market.totalCollateral(), expectedStaked);
        assertEq(market.socFeePending(), totalCollat - expectedStaked);

        uint256 shares = (USGToFlashMint * RAY) / index;

        assertEq(market.userDebt(usr3), (shares * index) / RAY);
        assertEq(market.totalDebt(), (shares * index) / RAY);

        assertEq(market.userDebtShares(usr3), shares);
        assertEq(market.totalDebtShares(), shares);

        assertERC20Tracking();
    }

    function test_leverage_to_limit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 USGToFlashMint = 20_000 ether;
        uint256 collatReceived = 19_000 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER_V2), address(mockRouter), abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector));

        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, collatToDeposit);

        // We put some collat in pending on the zapping for mocking
        deal(address(collatToken), address(zappingProxy), collatReceived * 10);

        verifyMintERC20(usg, USGToFlashMint, "Some USG are minted during leverage");

        market.leverage(
            collatToDeposit,
            USGToFlashMint,
            collatReceived,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), collatReceived)})
        );

        assertEq(IERC20(address(stakingProxy.gaugeAddress())).balanceOf(address(stakingProxy)), collatReceived + collatToDeposit, "Convex staking proxy received Fxn Gauge");
        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertApproxEqAbs(market.userDebt(usr1), USGToFlashMint, 5);

        assertERC20Tracking();

        skip(7 days);

        rewardAccumulator.processRewards(address(market), usr2);

        skip(7 days);

        rewardAccumulator.claimSimple(address(market));

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardToSimpleClaim.selector));
        rewardAccumulator.claimSimple(address(market));

        market.leverage(
            0,
            15_000 ether,
            0,
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), 14_000 ether)})
        );
    }

    function test_leverage_small_USG_amount() external {
        vm.startPrank(usr1);

        uint256 collatToDeposit = 10_000 ether;
        uint256 initialBorrow = 3_000 ether;
        uint256 USGToFlashMint = 1000;
        uint256 collatReceived = 999;

        // Prepare user
        collatToken.approve(address(market), MAX_UINT);
        // Put some collat on the mocked router, ready to be sent back to the market
        deal(address(collatToken), address(mockRouter), collatToDeposit);

        market.depositAndBorrow(collatToDeposit, initialBorrow);

        verifyMintERC20(usg, USGToFlashMint, "Some USG are minted during leverage");
        verifyBalERC20NotChanging(collatToken, usr1, "No collat token taken from usr1");

        market.leverage(
            0,
            USGToFlashMint,
            collatReceived,
            // Simulate zap call with a transfer to the market
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, USGToFlashMint, collatToken, address(market), collatReceived)
        );

        uint256 index = irCalculator.debtIndexes(address(market));

        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertEq(market.socFeePending(), 0);

        assertApproxEqAbs(market.userDebt(usr1), USGToFlashMint + initialBorrow, 5, "UserDebt");
        assertApproxEqAbs(market.totalDebt(), USGToFlashMint + initialBorrow, 5, "Total debt");

        uint256 expectedShares = ((initialBorrow * RAY) / index) + ((USGToFlashMint * RAY) / index);

        assertEq(market.userDebtShares(usr1), expectedShares);
        assertEq(market.totalDebtShares(), expectedShares);

        assertERC20Tracking();
    }
}

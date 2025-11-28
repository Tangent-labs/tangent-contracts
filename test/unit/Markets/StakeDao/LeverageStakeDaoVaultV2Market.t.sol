// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Curve/HLPManipulator.sol";
contract LeverageStakeDaoVaultV2Market is MarketDeploymentContext {
    StakeDaoVaultV2Market public market;
    IERC20Metadata public collatToken;
    IERC20 public vault;

    HLPManipulator hLpManipulator;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployStakeDaoVaultV2Market(collatToken);
        vault = market.vaultToken();
        hLpManipulator = new HLPManipulator(usr2);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 1, 0, 400_000 ether);
        skip(30 minutes);
        irCalculator.checkpointIR(address(market));
        skip(500 days);
    }

    function test_leverage_StakeDaoVaultV2_with_vaultToken() external {
        vm.startPrank(usr3);
        uint256 collatToDeposit = 100_000 ether;
        uint256 usgToFlashMint = 200_000 ether;
        uint256 collatReceived = 190_000 ether;

        uint256 totalCollat = collatToDeposit + collatReceived;

        // Prepare user
        vault.approve(address(market), MAX_UINT);
        // Put some collat on the mocked router, ready to be sent back to the market
        deal(address(collatToken), address(mockRouter), collatReceived);

        verifyMintERC20(usg, usgToFlashMint, "Some USG are minted during leverage");
        verifyReceiveERC20(usg, address(mockRouter), usgToFlashMint, "USG are sent to the router");
        verifyLostERC20(vault, usr3, collatToDeposit, "Collat token taken from usr1");

        market.leverage(
            LeverageIn({collatToDeposit: collatToDeposit, usgToFlashMint: usgToFlashMint, minCollatAmountOut: collatReceived, isReceiptIn: true}),
            // Simulate zap call with a transfer to the market
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, usgToFlashMint, collatToken, address(market), collatReceived)
        );
        uint256 index = irCalculator.debtIndexes(address(market));

        assertEq(market.collateralBalances(usr3), totalCollat);
        assertEq(market.totalCollateral(), totalCollat);

        uint256 shares = (usgToFlashMint * RAY) / index;
        assertApproxEqAbs(market.userDebtShares(usr3), shares, 3);
        assertApproxEqAbs(market.totalDebtShares(), shares, 3);

        assertERC20Tracking();
    }

    function test_leverage_StakeDaoVaultV2_with_LP() external {
        vm.startPrank(usr3);
        uint256 collatToDeposit = 100_000 ether;
        uint256 usgToFlashMint = 200_000 ether;
        uint256 collatReceived = 190_000 ether;

        uint256 totalCollat = collatToDeposit + collatReceived;

        // Prepare user
        collatToken.approve(address(market), MAX_UINT);
        // Put some collat on the mocked router, ready to be sent back to the market
        deal(address(collatToken), address(mockRouter), collatReceived);

        verifyMintERC20(usg, usgToFlashMint, "Some USG are minted during leverage");
        verifyReceiveERC20(usg, address(mockRouter), usgToFlashMint, "USG are sent to the router");
        verifyLostERC20(collatToken, usr3, collatToDeposit, "Collat token taken from usr1");

        market.leverage(
            LeverageIn({collatToDeposit: collatToDeposit, usgToFlashMint: usgToFlashMint, minCollatAmountOut: collatReceived, isReceiptIn: false}),
            // Simulate zap call with a transfer to the market
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, usgToFlashMint, collatToken, address(market), collatReceived)
        );
        uint256 index = irCalculator.debtIndexes(address(market));

        assertEq(market.collateralBalances(usr3), totalCollat);
        assertEq(market.totalCollateral(), totalCollat);

        uint256 shares = (usgToFlashMint * RAY) / index;
        assertApproxEqAbs(market.userDebtShares(usr3), shares, 3);
        assertApproxEqAbs(market.totalDebtShares(), shares, 3);

        assertERC20Tracking();
    }

    function test_leverage_to_limit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 usgToFlashMint = 20_000 ether;
        uint256 collatReceived = 19_000 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER_V2), address(mockRouter), abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector));

        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, collatToDeposit);

        // We put some collat in pending on the zapping for mocking
        deal(address(collatToken), address(zappingProxy), collatReceived * 10);

        verifyMintERC20(usg, usgToFlashMint, "Some USG are minted during leverage");
        verifyLostERC20(collatToken, usr1, collatToDeposit, "Collat token taken from User1");
        verifyReceiveERC20(vault, address(market), collatToDeposit + collatReceived, "Vault token received by the market");

        market.leverage(
            LeverageIn({collatToDeposit: collatToDeposit, usgToFlashMint: usgToFlashMint, minCollatAmountOut: collatReceived, isReceiptIn: false}),
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), collatReceived)})
        );

        assertEq(vault.balanceOf(address(market)), collatReceived + collatToDeposit, "Vault token of StakeDao received by the market");
        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertApproxEqAbs(marketViewer.userDebt(market, usr1), usgToFlashMint, 5);

        assertERC20Tracking();

        skip(7 days);

        rewardAccumulator.processRewards(address(market), usr2);

        skip(7 days);

        rewardAccumulator.claimSimple(address(market));

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardToSimpleClaim.selector));
        rewardAccumulator.claimSimple(address(market));

        market.leverage(
            LeverageIn({collatToDeposit: 0, usgToFlashMint: 15_000 ether, minCollatAmountOut: 0, isReceiptIn: false}),
            // Simulate zap call with a transfer to the market
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(market), 14_000 ether)})
        );
    }

    function test_leverage_small_USG_amount() external {
        vm.startPrank(usr1);

        uint256 collatToDeposit = 10_000 ether;
        uint256 initialBorrow = 3_000 ether;
        uint256 usgToFlashMint = 1000;
        uint256 collatReceived = 999;

        // Prepare user
        collatToken.approve(address(market), MAX_UINT);
        // Put some collat on the mocked router, ready to be sent back to the market
        deal(address(collatToken), address(mockRouter), collatToDeposit);

        market.depositAndBorrow(collatToDeposit, initialBorrow, false);

        verifyMintERC20(usg, usgToFlashMint, "Some USG are minted during leverage");
        verifyBalERC20NotChanging(collatToken, usr1, "No collat token taken from usr1");

        market.leverage(
            LeverageIn({collatToDeposit: 0, usgToFlashMint: usgToFlashMint, minCollatAmountOut: collatReceived, isReceiptIn: false}),
            // Simulate zap call with a transfer to the market
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, usgToFlashMint, collatToken, address(market), collatReceived)
        );

        uint256 index = irCalculator.debtIndexes(address(market));

        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);

        assertApproxEqAbs(marketViewer.userDebt(market, usr1), usgToFlashMint + initialBorrow, 5, "UserDebt");
        assertApproxEqAbs(marketViewer.totalDebt(market), usgToFlashMint + initialBorrow, 5, "Total debt");

        uint256 expectedShares = ((initialBorrow * RAY) / index) + ((usgToFlashMint * RAY) / index);

        assertApproxEqAbs(market.userDebtShares(usr1), expectedShares, 4, "Expected shares not good");
        assertApproxEqAbs(market.totalDebtShares(), expectedShares, 4, "Expected total shares not good");

        assertGe(market.userDebtShares(usr1), expectedShares, "Slightly bigger because of ceiling");
        assertGe(market.totalDebtShares(), expectedShares, "Slightly bigger because of ceiling");

        assertERC20Tracking();
    }
}

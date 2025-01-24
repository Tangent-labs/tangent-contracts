// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";

contract LeverageToTheLimit is ConvexCurveContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;

    IStakingProxyERC20 stakingProxy;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_FXUSD;
        market = deployConvexFxnLPMarket(collatToken);

        minimumLoan = market.minimumLoan();

        stakingProxy = market.stakingProxyVault();
    }

    function test_leverage_without_deposit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 0;
        uint256 tgUSDToFlashMint = 10_000 ether;
        uint256 collatReceived = 9_995 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouter.routeSingle.selector));
        bytes memory callRouter = ensoUtils.getZapCallMocked(address(tgUsd), tgUSDToFlashMint, address(collatToken), mockedLP, address(market), address(zapper), collatReceived);

        // Revert beaucause LTV is too low
        vm.expectRevert(abi.encodeWithSelector(MarketCore.PositionDebtTooHigh.selector));
        market.leverage(collatToDeposit, tgUSDToFlashMint, collatReceived, address(zapper), true, callRouter);
    }

    function test_leverage_to_limit() external {
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 tgUSDToFlashMint = 20_000 ether;
        uint256 collatReceived = 19_000 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouter.routeSingle.selector));

        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, collatToDeposit);

        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            collatReceived,
            address(zapper),
            true,
            ensoUtils.getZapCallMocked(address(tgUsd), tgUSDToFlashMint, address(collatToken), mockedLP, address(market), address(zapper), collatReceived)
        );

        assertEq(IERC20(stakingProxy.gaugeAddress()).balanceOf(address(stakingProxy)), collatReceived + collatToDeposit, "Convex staking proxy received Fxn Gauge");
        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertEq(market.positionDebt(usr1), tgUSDToFlashMint);

        skip(7 days);

        market.processRewards(usr2);
    }
}

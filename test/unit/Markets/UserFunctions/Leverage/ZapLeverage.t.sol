// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ZapLeverage is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;

    IStakingProxyERC20 stakingProxy;

    HLPManipulator hLpManipulator;

    uint256 ethIn = 100 ether;
    uint256 usdtIn = 220_000 ether;

    uint256 collatReceivedFromZap = 200_000 ether;

    uint256 USGToFlashMint = 750_000 ether;
    uint256 collatReceivedFromLeverage = 700_000 ether;

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

    function test_zapLeverage_with_eth() external {
        uint256 totalCollat = collatReceivedFromZap + collatReceivedFromLeverage;
        vm.startPrank(usr4);

        deal(usr4, ethIn);
        deal(address(collatToken), address(mockRouter), collatReceivedFromZap + collatReceivedFromLeverage);

        verifyMintERC20(usg, USGToFlashMint, "Some USG are minted during leverage");
        verifyReceiveERC20(usg, address(mockRouter), USGToFlashMint, "USG are sent to the router");

        verifyLostERC20(ETH_NAKED, usr4, ethIn, "ETH token taken from usr1");

        market.zapLeverage{value: ethIn}(
            USGToFlashMint,
            collatReceivedFromLeverage,
            // Swap of USG to collat
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, USGToFlashMint, collatToken, address(market), collatReceivedFromLeverage),
            // Swap of ETH to collat
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: ethIn,
                minAmountOut: 99_000 ether,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, ethIn, collatToken, address(market), collatReceivedFromZap)
            })
        );

        uint256 index = irCalculator.debtIndexes(address(market));

        uint256 shares = (USGToFlashMint * RAY) / index;

        assertEq(market.collateralBalances(usr4), totalCollat);
        assertEq(market.totalCollateral(), totalCollat);

        assertApproxEqAbs(marketViewer.userDebt(market, usr4), (shares * index) / RAY, 3);
        assertApproxEqAbs(marketViewer.totalDebt(market), (shares * index) / RAY, 3);

        assertERC20Tracking();
    }

    function test_zapLeverage_with_erc20() external {
        uint256 totalCollat = collatReceivedFromZap + collatReceivedFromLeverage;
        vm.startPrank(usr4);

        AddrClassicERC20.USDT.forceApprove(address(market), MAX_UINT);
        deal(address(AddrClassicERC20.USDT), usr4, usdtIn);
        deal(address(collatToken), address(mockRouter), collatReceivedFromZap + collatReceivedFromLeverage);

        verifyMintERC20(usg, USGToFlashMint, "Some USG are minted during leverage");
        verifyReceiveERC20(usg, address(mockRouter), USGToFlashMint, "USG are sent to the router");

        verifyLostERC20(AddrClassicERC20.USDT, usr4, usdtIn, "USDT token taken from usr1");

        market.zapLeverage(
            USGToFlashMint,
            collatReceivedFromLeverage,
            // Swap of USG to collat
            encoder.encodeSwapToMockRouter(address(mockRouter), usg, USGToFlashMint, collatToken, address(market), collatReceivedFromLeverage),
            // Swap of ETH to collat
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: usdtIn,
                minAmountOut: 99_000 ether,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, usdtIn, collatToken, address(market), collatReceivedFromZap)
            })
        );
        uint256 index = irCalculator.debtIndexes(address(market));
        uint256 shares = (USGToFlashMint * RAY) / index;

        assertEq(market.collateralBalances(usr4), totalCollat);
        assertEq(market.totalCollateral(), totalCollat);

        assertApproxEqRel(marketViewer.userDebt(market, usr4), (shares * index) / RAY, 3);
        assertApproxEqRel(marketViewer.totalDebt(market), (shares * index) / RAY, 3);

        assertERC20Tracking();

        skip(60 days);

        vm.startPrank(usr1);
        uint256 uDebt = marketViewer.userDebt(market, usr4);

        deal(address(usg), address(mockRouter), uDebt + (market.liquidationFee() * uDebt) / 100_000);

        market.liquidate(
            LiquidateIn({
                account: usr4,
                postLiquidate: PostLiquidate({
                    collatAmountToLiquidate: market.collateralBalances(usr4),
                    minUsgOut: market.collateralBalances(usr4),
                    maxUsgToBurn: MAX_UINT,
                    minCollatAmountToLiquidate: 0,
                    isReceiptOut: false
                }),
                minCollatValueToLiquidate: 0
            }),
            encoder.encodeSwapToMockRouter(address(mockRouter), collatToken, totalCollat, usg, usr1, uDebt + (market.liquidationFee() * uDebt) / 100_000)
        );

        assertEq(market.collateralBalances(usr4), 0);
        assertEq(market.totalCollateral(), 0);

        assertEq(marketViewer.userDebt(market, usr4), 0);
        assertEq(marketViewer.totalDebt(market), 0);

        assertEq(market.userDebtShares(usr4), 0);
        assertEq(market.totalDebtShares(), 0);
    }
}

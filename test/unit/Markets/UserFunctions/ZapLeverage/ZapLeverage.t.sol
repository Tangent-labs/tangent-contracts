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

    uint256 tgUSDToFlashMint = 750_000 ether;
    uint256 collatReceivedFromLeverage = 700_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        minimumLoan = market.minimumLoan();

        stakingProxy = market.stakingProxyVault();

        hLpManipulator = new HLPManipulator(usr2);

        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 1, 0, 400_000 ether);
        skip(30 minutes);
        irCalculator.checkpointIR(address(market));
        skip(500 days);
    }

    function test_zapLeverage_with_eth() external {
        uint256 totalCollat = collatReceivedFromZap + collatReceivedFromLeverage;
        vm.startPrank(usr4);

        deal(usr4, ethIn);
        deal(address(collatToken), address(mockRouter), collatReceivedFromZap + collatReceivedFromLeverage);

        verifyMintERC20(tgUSD, tgUSDToFlashMint, "Some tgUSD are minted during leverage");
        verifyReceiveERC20(tgUSD, address(mockRouter), tgUSDToFlashMint, "TgUSD are sent to the router");

        verifyLostERC20(ETH_NAKED, usr4, ethIn, "ETH token taken from usr1");
        verifyReceiveERC20(collatToken, address(market), collatReceivedFromZap + collatReceivedFromLeverage, "Collat token received by the market");

        market.zapLeverage{value: ethIn}(
            tgUSDToFlashMint,
            collatReceivedFromLeverage,
            false,
            // Swap of tgUSD to collat
            encoder.encodeSwapToMockRouter(address(mockRouter), tgUSD, tgUSDToFlashMint, collatToken, address(market), collatReceivedFromLeverage),
            // Swap of ETH to collat
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: ethIn,
                minAmountOut: 99_000 ether,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, ethIn, collatToken, address(market), collatReceivedFromZap)
            })
        );

        uint256 index = irCalculator.debtIndexes(address(market));

        uint256 shares = (tgUSDToFlashMint * RAY) / index;

        uint256 expectedStaked = (totalCollat * (100_000 - market.socFeePercentage())) / 100_000;
        assertEq(market.collateralBalances(usr4), expectedStaked);
        assertEq(market.totalCollateral(), expectedStaked);
        assertEq(market.socFeePending(), totalCollat - expectedStaked);

        assertEq(market.userDebt(usr4), (shares * index) / RAY);
        assertEq(market.totalDebt(), (shares * index) / RAY);

        assertERC20Tracking();
    }

    function test_zapLeverage_with_erc20() external {
        uint256 totalCollat = collatReceivedFromZap + collatReceivedFromLeverage;
        vm.startPrank(usr4);

        AddrClassicERC20.USDT.forceApprove(address(market), MAX_UINT);
        deal(address(AddrClassicERC20.USDT), usr4, usdtIn);
        deal(address(collatToken), address(mockRouter), collatReceivedFromZap + collatReceivedFromLeverage);

        verifyMintERC20(tgUSD, tgUSDToFlashMint, "Some tgUSD are minted during leverage");
        verifyReceiveERC20(tgUSD, address(mockRouter), tgUSDToFlashMint, "TgUSD are sent to the router");

        verifyLostERC20(AddrClassicERC20.USDT, usr4, usdtIn, "USDT token taken from usr1");

        market.zapLeverage(
            tgUSDToFlashMint,
            collatReceivedFromLeverage,
            true,
            // Swap of tgUSD to collat
            encoder.encodeSwapToMockRouter(address(mockRouter), tgUSD, tgUSDToFlashMint, collatToken, address(market), collatReceivedFromLeverage),
            // Swap of ETH to collat
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: usdtIn,
                minAmountOut: 99_000 ether,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, usdtIn, collatToken, address(market), collatReceivedFromZap)
            })
        );
        uint256 index = irCalculator.debtIndexes(address(market));
        uint256 shares = (tgUSDToFlashMint * RAY) / index;

        assertEq(market.collateralBalances(usr4), totalCollat);
        assertEq(market.totalCollateral(), totalCollat);
        assertEq(market.socFeePending(), 0);

        assertEq(market.userDebt(usr4), (shares * index) / RAY);
        assertEq(market.totalDebt(), (shares * index) / RAY);

        assertERC20Tracking();

        skip(60 days);

        vm.startPrank(usr1);
        uint256 uDebt = market.userDebt(usr4);

        deal(address(tgUSD), address(mockRouter), uDebt + (market.liquidationFee() * uDebt) / 100_000);

        market.liquidate(
            usr4,
            market.collateralBalances(usr4),
            0,
            encoder.encodeSwapToMockRouter(address(mockRouter), collatToken, totalCollat, tgUSD, usr1, uDebt + (market.liquidationFee() * uDebt) / 100_000)
        );

        assertEq(market.collateralBalances(usr4), 0);
        assertEq(market.totalCollateral(), 0);
        assertEq(market.socFeePending(), 0);

        assertEq(market.userDebt(usr4), 0);
        assertEq(market.totalDebt(), 0);

        assertEq(market.userDebtShares(usr4), 0);
        assertEq(market.totalDebtShares(), 0);
    }
}

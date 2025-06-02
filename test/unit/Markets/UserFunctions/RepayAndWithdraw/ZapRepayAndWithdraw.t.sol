// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../handler/Features/ConvexCrv/HZapDepositConvexCrvLP.sol";

contract ZapRepayAndWithdraw is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.sDAI_sUSDe;

    uint256 depositedAmount = 333_333 ether;
    uint256 withdrawnAmount = 50_000 ether;

    uint256 debtBorrow = 200_000 ether;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, false);

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(depositedAmount, debtBorrow, true);
    }

    function test_zapRepayAndWithdraw_partial_with_eth() external {
        vm.startPrank(usr1);

        uint256 amountIn = 5 ether;
        uint256 tgUSDBought = 15_000 ether;
        deal(usr1, amountIn);
        deal(address(tgUSD), address(mockRouter), tgUSDBought);

        verifyBurnERC20(tgUSD, tgUSDBought);
        verifyLostERC20(ETH_NAKED, usr1, amountIn);

        verifyReceiveERC20(collatToken, usr1, withdrawnAmount);
        verifyLostERC20(collatToken, address(market), withdrawnAmount);

        market.zapRepayAndWithdraw{value: amountIn}(
            withdrawnAmount,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: tgUSDBought,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, tgUSD, address(usr1), tgUSDBought)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount - withdrawnAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount - withdrawnAmount);

        assertEq(market.userDebt(usr1), debtBorrow - tgUSDBought);
        assertEq(market.totalDebt(), debtBorrow - tgUSDBought);
    }

    function test_zapRepayAndWithdraw_fullRepay_partialWithdraw_with_erc20() external {
        vm.startPrank(usr1);

        IERC20 tokenIn = AddrClassicERC20.USDe;

        uint256 amountReturnZap = debtBorrow + 1_000 ether;

        deal(address(tokenIn), usr1, debtBorrow);
        deal(address(tgUSD), address(mockRouter), amountReturnZap);

        verifyBurnERC20(tgUSD, debtBorrow);
        verifyLostERC20(tokenIn, usr1, debtBorrow);

        verifyReceiveERC20(tgUSD, usr1, amountReturnZap - debtBorrow);
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount);
        verifyLostERC20(collatToken, address(market), withdrawnAmount);

        tokenIn.approve(address(market), MAX_UINT);
        market.zapRepayAndWithdraw(
            withdrawnAmount,
            ZapStructDeposit({
                tokenIn: tokenIn,
                amountIn: debtBorrow,
                minAmountOut: amountReturnZap,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), tokenIn, debtBorrow, tgUSD, address(usr1), amountReturnZap)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount - withdrawnAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount - withdrawnAmount);

        assertEq(market.userDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        market.withdraw(depositedAmount - withdrawnAmount);

        assertEq(market.totalCollateral(), 0);
        assertEq(market.collateralBalances(usr1), 0);
    }

    function test_zapRepayAndWithdraw_fullWithdraw_fullRepay() external {
        vm.startPrank(usr2);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(depositedAmount, debtBorrow, false);

        IERC20 tokenIn = AddrClassicERC20.frxUSD;
        uint256 amountReturnZap = debtBorrow + 1_000 ether;

        deal(address(tokenIn), usr2, debtBorrow);
        deal(address(tgUSD), address(mockRouter), amountReturnZap);

        verifyBurnERC20(tgUSD, debtBorrow);
        verifyReceiveERC20(tgUSD, usr2, amountReturnZap - debtBorrow);
        verifyLostERC20(tokenIn, usr2, debtBorrow);

        verifyReceiveERC20(collatToken, usr2, depositedAmount);
        verifyLostERC20(collatToken, address(market), depositedAmount);

        tokenIn.approve(address(market), MAX_UINT);
        market.zapRepayAndWithdraw(
            depositedAmount,
            ZapStructDeposit({
                tokenIn: tokenIn,
                amountIn: debtBorrow,
                minAmountOut: amountReturnZap,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), tokenIn, debtBorrow, tgUSD, address(usr2), amountReturnZap)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount);

        assertEq(market.userDebt(usr1), debtBorrow);
        assertEq(market.totalDebt(), debtBorrow);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../../contexts/MarketDeploymentContext.sol";

contract ZapRepayAndWithdraw is MarketDeploymentContext {
    BasicERC20Market public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.sDAI_sUSDe;

    uint256 depositedAmount = 333_333 ether;
    uint256 withdrawnAmount = 50_000 ether;

    uint256 debtBorrow = 200_000 ether;

    function setUp() public {
        market = deployBasicERC20Market(collatToken);

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(depositedAmount, debtBorrow, false);
    }

    function test_zapRepayAndWithdraw_partial_with_eth() external {
        vm.startPrank(usr1);

        uint256 amountIn = 5 ether;
        uint256 USGBought = 15_000 ether;
        deal(usr1, amountIn);
        deal(address(usg), address(mockRouter), USGBought);

        verifyBurnERC20(usg, USGBought);
        verifyLostERC20(ETH_NAKED, usr1, amountIn);

        verifyReceiveERC20(collatToken, usr1, withdrawnAmount);
        verifyLostERC20(collatToken, address(market), withdrawnAmount);

        market.zapRepayAndWithdraw{value: amountIn}(
            withdrawnAmount,
            false,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: USGBought,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, usg, address(usr1), USGBought)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount - withdrawnAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount - withdrawnAmount);

        assertEq(marketViewer.userDebt(market, usr1), debtBorrow - USGBought);
        assertEq(marketViewer.totalDebt(market), debtBorrow - USGBought);
    }

    function test_zapRepayAndWithdraw_fullRepay_partialWithdraw_with_erc20() external {
        vm.startPrank(usr1);

        IERC20 tokenIn = AddrClassicERC20.USDe;

        uint256 amountReturnZap = debtBorrow + 1_000 ether;

        deal(address(tokenIn), usr1, debtBorrow);
        deal(address(usg), address(mockRouter), amountReturnZap);

        verifyBurnERC20(usg, debtBorrow);
        verifyLostERC20(tokenIn, usr1, debtBorrow);

        verifyReceiveERC20(usg, usr1, amountReturnZap - debtBorrow);
        verifyReceiveERC20(collatToken, usr1, withdrawnAmount);
        verifyLostERC20(collatToken, address(market), withdrawnAmount);

        tokenIn.approve(address(market), MAX_UINT);
        market.zapRepayAndWithdraw(
            withdrawnAmount,
            false,
            ZapStructDeposit({
                tokenIn: tokenIn,
                amountIn: debtBorrow,
                minAmountOut: amountReturnZap,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), tokenIn, debtBorrow, usg, address(usr1), amountReturnZap)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount - withdrawnAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount - withdrawnAmount);

        assertEq(marketViewer.userDebt(market, usr1), 0);
        assertEq(marketViewer.totalDebt(market), 0);

        market.withdraw(depositedAmount - withdrawnAmount, false);

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
        deal(address(usg), address(mockRouter), amountReturnZap);

        verifyBurnERC20(usg, debtBorrow);
        verifyReceiveERC20(usg, usr2, amountReturnZap - debtBorrow);
        verifyLostERC20(tokenIn, usr2, debtBorrow);

        verifyReceiveERC20(collatToken, usr2, depositedAmount);
        verifyLostERC20(collatToken, address(market), depositedAmount);

        tokenIn.approve(address(market), MAX_UINT);
        market.zapRepayAndWithdraw(
            depositedAmount,
            false,
            ZapStructDeposit({
                tokenIn: tokenIn,
                amountIn: debtBorrow,
                minAmountOut: amountReturnZap,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), tokenIn, debtBorrow, usg, address(usr2), amountReturnZap)
            })
        );
        assertERC20Tracking();

        assertEq(market.totalCollateral(), depositedAmount);
        assertEq(market.collateralBalances(usr1), depositedAmount);

        assertEq(marketViewer.userDebt(market, usr1), debtBorrow);
        assertEq(marketViewer.totalDebt(market), debtBorrow);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract LeverageReverts is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;

    ConvexCrvLPMarket public market;
    HDepositConvexCrvLP public hDeposit;
    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        minimumLoan = market.minimumLoan();
        maxMarketDebt = market.maxMarketDebt();
    }

    function test_leverage_when_deposit_paused() external {
        vm.startPrank(pauser);
        market.setPause(PauseSettings.PauseEnum.DepositPaused, 1);

        vm.expectRevert(abi.encodeWithSelector(PauseSettings.DepositPaused.selector));
        market.leverage(
            LeverageIn({collatToDeposit: 0, usgToFlashMint: 10, minCollatAmountOut: 100, isReceiptIn: false}),
            ZapStruct({router: address(collatToken), routerCall: ""})
        );
    }

    function test_leverage_when_borrow_paused() external {
        uint256 USGMinted = 10_000 ether;
        uint256 collatOut = 5_000 ether;

        deal(address(collatToken), address(mockRouter), collatOut);

        vm.startPrank(pauser);
        market.setPause(PauseSettings.PauseEnum.BorrowPaused, 1);
        ZapStruct memory zap = encoder.encodeSwapToMockRouter(address(mockRouter), usg, USGMinted, collatToken, address(market), collatOut);
        vm.expectRevert(abi.encodeWithSelector(PauseSettings.BorrowPaused.selector));
        market.leverage(LeverageIn({collatToDeposit: 0, usgToFlashMint: USGMinted, minCollatAmountOut: collatOut, isReceiptIn: false}), zap);
    }

    function test_leverage_when_leverage_paused() external {
        vm.startPrank(pauser);
        market.setPause(PauseSettings.PauseEnum.LeveragePaused, 1);

        vm.expectRevert(abi.encodeWithSelector(PauseSettings.LeveragePaused.selector));
        market.leverage(
            LeverageIn({collatToDeposit: 0, usgToFlashMint: 10, minCollatAmountOut: 100, isReceiptIn: false}),
            ZapStruct({router: address(collatToken), routerCall: ""})
        );
    }
}

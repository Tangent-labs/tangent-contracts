// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/BorrowRepay/HRepay.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract LeverageReverts is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;

    ConvexCrvLPMarket public market;
    HDepositConvexCrvLP public hDeposit;
    uint256 minimumLoan;
    uint256 maxMarketDebt;
    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        minimumLoan = market.minimumLoan();
        maxMarketDebt = market.maxMarketDebt();
    }

    function test_leverage_when_deposit_paused() external {
        vm.startPrank(owner);
        market.setIsDepositPaused(true);

        vm.expectRevert(abi.encodeWithSelector(MarketCore.DepositPaused.selector));
        market.leverage(0, 10, 100, true, ZapStruct({router: address(collatToken), routerCall: ""}));
    }

    function test_leverage_when_borrow_paused() external {
        vm.startPrank(owner);
        market.setIsBorrowPaused(true);

        vm.expectRevert(abi.encodeWithSelector(MarketCore.BorrowPaused.selector));
        market.leverage(0, 10, 100, true, ZapStruct({router: address(collatToken), routerCall: ""}));
    }

    function test_leverage_when_leverage_paused() external {
        vm.startPrank(owner);
        market.setIsLeveragePaused(true);

        vm.expectRevert(abi.encodeWithSelector(MarketCore.LeveragePaused.selector));
        market.leverage(0, 10, 100, true, ZapStruct({router: address(collatToken), routerCall: ""}));
    }
}

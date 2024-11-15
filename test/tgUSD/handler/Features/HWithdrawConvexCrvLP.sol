// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../Base/HMarketBase.sol";

contract HWithdrawConvexCrvLP is HMarketBase {
    constructor(address _sender, ConvexCrvLPMarket _market) HandlerBase(_sender, _market) {}

    function withdraw(uint256 lpToWithdraw) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        market.withdraw(lpToWithdraw);

        _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function withdrawAndBorrow(uint256 lpToWithdraw, uint256 debtBorrow) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        market.withdrawAndBorrow(lpToWithdraw, debtBorrow);

        _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function withdrawAndRepay(uint256 lpToWithdraw, uint256 debtRepay) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        market.withdrawAndRepay(lpToWithdraw, debtRepay);

        _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function _beforeWithdrawCheck(uint256 lpToWithdraw) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
        IERC20 collatToken = market.collatToken();

        totalCollateralBefore = market.totalCollateral();
        balanceCollateralBefore = market.collateralBalances(sender);

        verifyReceiveERC20(collatToken, sender, lpToWithdraw, "Collat is withdrawn and sent to sender");

        // TODO Verify withdraw occurs properly by withdrawing first non staked assets
    }

    function _afterWithdrawCheck(uint256 lpToWithdraw, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
        assertEq(market.totalCollateral(), totalCollateralBefore - lpToWithdraw, "Total collateral is decreased by the amount withdrawn");
        assertEq(market.collateralBalances(sender), balanceCollateralBefore - lpToWithdraw, "Collateral of the user is decreased by the amount withdrawn");
    }
}

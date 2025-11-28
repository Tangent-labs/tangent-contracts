// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../src/USG/Market/Convex/ConvexCrvLPMarket.sol";

contract HWithdrawConvexCrvLP is HMarketBase {
    ConvexCrvLPMarket marketCrvLP;
    constructor(address _sender, ConvexCrvLPMarket _market, IERC20 _usg, MarketViewer _marketViewer) HandlerBase(_sender, _market, _usg, _marketViewer) {
        marketCrvLP = ConvexCrvLPMarket(address(_market));
    }

    function withdraw(uint256 lpToWithdraw, bool isReceiptOut) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        marketCrvLP.withdraw(lpToWithdraw, isReceiptOut);

        _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function repayAndWithdraw(uint256 lpToWithdraw, uint256 debtRepay, bool isReceiptOut) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        marketCrvLP.repayAndWithdraw(lpToWithdraw, debtRepay, isReceiptOut);

        _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function _beforeWithdrawCheck(uint256 lpToWithdraw) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
        IERC20 collatToken = marketCrvLP.collatToken();

        totalCollateralBefore = marketCrvLP.totalCollateral();
        balanceCollateralBefore = marketCrvLP.collateralBalances(sender);

        verifyReceiveERC20(collatToken, sender, lpToWithdraw, "Collat is withdrawn and sent to sender");
    }

    function _afterWithdrawCheck(uint256 lpToWithdraw, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
        assertEq(marketCrvLP.totalCollateral(), totalCollateralBefore - lpToWithdraw, "Total collateral is decreased by the amount withdrawn");
        assertEq(marketCrvLP.collateralBalances(sender), balanceCollateralBefore - lpToWithdraw, "Collateral of the user is decreased by the amount withdrawn");
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../src/USG/Market/Convex/ConvexFxnLPMarket.sol";

contract HDepositConvexFxnLP is HMarketBase {
    ConvexFxnLPMarket marketFxnLP;
    constructor(address _sender, ConvexFxnLPMarket _market, IERC20 _usg, MarketViewer _marketViewer) HandlerBase(_sender, _market, _usg, _marketViewer) {
        marketFxnLP = ConvexFxnLPMarket(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited, bool isReceiptIn) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(_for, lpDeposited);

        marketFxnLP.deposit(_for, lpDeposited, isReceiptIn);

        _afterDepositCheck(_for, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isReceiptIn) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(sender, lpDeposited);
        DebtData memory debtData = _beforBorrowOrRepayCheck(marketFxnLP);
        _beforeBorrowCheck(marketFxnLP, sender, borrowedAmount);

        marketFxnLP.depositAndBorrow(lpDeposited, borrowedAmount, isReceiptIn);

        _afterDepositCheck(sender, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
        _afterBorrowCheck(market, borrowedAmount, debtData.newDebtIndex, debtData.userDebtShares, debtData.totalDebtShares);
    }

    function _beforeDepositCheck(address _for, uint256 lpDeposited) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
        IERC20 collatToken = marketFxnLP.collatToken();

        collatToken.approve(address(marketFxnLP), MAX_UINT);

        totalCollateralBefore = marketFxnLP.totalCollateral();
        balanceCollateralBefore = marketFxnLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");

        uint256 collatMarketBalance = collatToken.balanceOf(address(marketFxnLP));

        verifyLostERC20(collatToken, address(marketFxnLP), collatMarketBalance, "Collat in pending is staked by the marketFxnLP");
    }

    function _afterDepositCheck(address _for, uint256 lpDeposited, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
        assertEq(lpDeposited, marketFxnLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by taking into account the pending sociabilization fee");
        assertEq(lpDeposited, marketFxnLP.collateralBalances(_for) - balanceCollateralBefore, "Collateral of the user is increased by taking into account pending soc fee");
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../src/USG/Market/Convex/ConvexCrvLPMarket.sol";

contract HDepositConvexCrvLP is HMarketBase {
    ConvexCrvLPMarket marketCrvLP;
    constructor(address _sender, ConvexCrvLPMarket _market, IERC20 _usg, MarketViewer _marketViewer) HandlerBase(_sender, _market, _usg, _marketViewer) {
        marketCrvLP = ConvexCrvLPMarket(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited, bool isReceiptIn) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(_for, lpDeposited);

        marketCrvLP.deposit(_for, lpDeposited, isReceiptIn);

        _afterDepositCheck(_for, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isReceiptIn) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(sender, lpDeposited);
        DebtData memory debtData = _beforBorrowOrRepayCheck(marketCrvLP);
        _beforeBorrowCheck(marketCrvLP, sender, borrowedAmount);

        marketCrvLP.depositAndBorrow(lpDeposited, borrowedAmount, isReceiptIn);

        _afterDepositCheck(sender, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
        _afterBorrowCheck(market, borrowedAmount, debtData.newDebtIndex, debtData.userDebtShares, debtData.totalDebtShares);
    }

    function _beforeDepositCheck(address _for, uint256 lpDeposited) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
        IERC20 collatToken = marketCrvLP.collatToken();

        collatToken.approve(address(marketCrvLP), MAX_UINT);

        totalCollateralBefore = marketCrvLP.totalCollateral();
        balanceCollateralBefore = marketCrvLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");

        // Connected to Convex
        if (marketCrvLP.pid() != 0) {
            uint256 collatMarketBalance = collatToken.balanceOf(address(marketCrvLP));
            verifyBalERC20NotChanging(collatToken, address(marketCrvLP), "There were no collat on the marketCrvLP waiting to be staked");
            verifyReceiveERC20(marketCrvLP.cvxRewardToken(), address(marketCrvLP), collatMarketBalance + lpDeposited, "Collat is received by the staking contract");
        } else {
            verifyReceiveERC20(collatToken, address(marketCrvLP), lpDeposited, "Collat is fully received by the marketCrvLP");
        }
    }

    function _afterDepositCheck(address _for, uint256 lpDeposited, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
        assertEq(lpDeposited, marketCrvLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by taking into account the pending sociabilization fee");
        assertEq(lpDeposited, marketCrvLP.collateralBalances(_for) - balanceCollateralBefore, "Collateral of the user is increased by taking into account pending soc fee");
    }
}

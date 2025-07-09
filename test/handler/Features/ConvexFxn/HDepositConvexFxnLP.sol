// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../src/USG/Market/Convex/ConvexFxnLPMarket.sol";

contract HDepositConvexFxnLP is HMarketBase {
    ConvexFxnLPMarket marketFxnLP;
    constructor(address _sender, ConvexFxnLPMarket _market) HandlerBase(_sender, _market) {
        marketFxnLP = ConvexFxnLPMarket(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(_for, lpDeposited);

        marketFxnLP.deposit(_for, lpDeposited);

        _afterDepositCheck(_for, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeDepositCheck(sender, lpDeposited);
        DebtData memory debtData = _beforBorrowOrRepayCheck(marketFxnLP);
        _beforeBorrowCheck(marketFxnLP, sender, borrowedAmount);

        marketFxnLP.depositAndBorrow(lpDeposited, borrowedAmount);

        _afterDepositCheck(sender, lpDeposited, totalCollateralBefore, balanceCollateralBefore);
        // _afterBorrowCheck(marketFxnLP, borrowedAmount, interests, newDebtIndex, userDebtShares, oldTotalDebtShares);
    }

    function _beforeDepositCheck(address _for, uint256 lpDeposited) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
        IERC20 collatToken = marketFxnLP.collatToken();

        collatToken.approve(address(marketFxnLP), MAX_UINT);

        totalCollateralBefore = marketFxnLP.totalCollateral();
        balanceCollateralBefore = marketFxnLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");

        uint256 collatMarketBalance = collatToken.balanceOf(address(marketFxnLP));

        verifyLostERC20(collatToken, address(marketFxnLP), collatMarketBalance, "Collat in pending is staked by the marketFxnLP");

        // verifyReceiveERC20(
        //     marketFxnLP.cvxRewardToken(),
        //     address(marketFxnLP),
        //     collatMarketBalance + lpDeposited,
        //     "Collat is received by the staking contract"
        // );
    }

    function _afterDepositCheck(address _for, uint256 lpDeposited, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
        assertEq(lpDeposited, marketFxnLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by taking into account the pending sociabilization fee");
        assertEq(lpDeposited, marketFxnLP.collateralBalances(_for) - balanceCollateralBefore, "Collateral of the user is increased by taking into account pending soc fee");
    }
}

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
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(_for, lpDeposited);

        marketFxnLP.deposit(_for, lpDeposited);

        _afterDepositCheck(_for, lpDeposited, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(sender, lpDeposited);
        DebtData memory debtData = _beforBorrowOrRepayCheck(marketFxnLP);
        _beforeBorrowCheck(marketFxnLP, sender, borrowedAmount);

        marketFxnLP.depositAndBorrow(lpDeposited, borrowedAmount);

        _afterDepositCheck(sender, lpDeposited, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
        // _afterBorrowCheck(marketFxnLP, borrowedAmount, interests, newDebtIndex, userDebtShares, oldTotalDebtShares);
    }

    function _beforeDepositCheck(
        address _for,
        uint256 lpDeposited
    ) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) {
        IERC20 collatToken = marketFxnLP.collatToken();
        socFeePending = marketFxnLP.socFeePending();

        collatToken.approve(address(marketFxnLP), MAX_UINT);

        totalCollateralBefore = marketFxnLP.totalCollateral();
        balanceCollateralBefore = marketFxnLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");

        uint256 collatMarketBalance = collatToken.balanceOf(address(marketFxnLP));
        if (socFeePending != 0) {
            verifyLostERC20(collatToken, address(marketFxnLP), collatMarketBalance, "Collat in pending is staked by the marketFxnLP");
        } else {
            verifyBalERC20NotChanging(collatToken, address(marketFxnLP), "There were no collat on the marketFxnLP waiting to be staked");
        }
        // verifyReceiveERC20(
        //     marketFxnLP.cvxRewardToken(),
        //     address(marketFxnLP),
        //     collatMarketBalance + lpDeposited,
        //     "Collat is received by the staking contract"
        // );
    }

    function _afterDepositCheck(
        address _for,
        uint256 lpDeposited,
        uint256 totalCollateralBefore,
        uint256 balanceCollateralBefore,
        uint256 socFeePending,
        uint256 feeToTake
    ) internal view {
        uint256 collatIncrease = lpDeposited + socFeePending;
        assertEq(0, marketFxnLP.socFeePending(), "When staked, fee pending are deleted");
        assertEq(collatIncrease, marketFxnLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by taking into account the pending sociabilization fee");
        assertEq(collatIncrease, marketFxnLP.collateralBalances(_for) - balanceCollateralBefore, "Collateral of the user is increased by taking into account pending soc fee");
    }
}

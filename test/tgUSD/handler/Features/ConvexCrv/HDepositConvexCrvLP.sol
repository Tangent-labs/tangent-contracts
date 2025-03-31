// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";

contract HDepositConvexCrvLP is HMarketBase {
    ConvexCrvLPMarket marketCrvLP;
    constructor(address _sender, ConvexCrvLPMarket _market) HandlerBase(_sender, _market) {
        marketCrvLP = ConvexCrvLPMarket(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(_for, lpDeposited, isStaked);

        marketCrvLP.deposit(_for, lpDeposited, isStaked);

        _afterDepositCheck(_for, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isStaked, address callerZapper) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(sender, lpDeposited, isStaked);
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, ) = _beforBorrowOrRepayCheck(marketCrvLP);
        _beforeBorrowCheck(marketCrvLP, sender, borrowedAmount);

        marketCrvLP.depositAndBorrow(lpDeposited, borrowedAmount, isStaked, callerZapper);

        _afterDepositCheck(sender, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
        _afterBorrowCheck(marketCrvLP, borrowedAmount, lastDebt, interests, newDebtIndex, positionDebt);
    }

    function _beforeDepositCheck(
        address _for,
        uint256 lpDeposited,
        bool isStaked
    ) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) {
        IERC20 collatToken = marketCrvLP.collatToken();
        uint256 socFeePercentage = marketCrvLP.socFeePercentage();
        socFeePending = marketCrvLP.socFeePending();

        collatToken.approve(address(marketCrvLP), MAX_UINT);

        totalCollateralBefore = marketCrvLP.totalCollateral();
        balanceCollateralBefore = marketCrvLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");
        if (isStaked) {
            uint256 collatMarketBalance = collatToken.balanceOf(address(marketCrvLP));
            if (socFeePending != 0) {
                verifyLostERC20(collatToken, address(marketCrvLP), collatMarketBalance, "Collat in pending is staked by the marketCrvLP");
            } else {
                verifyBalERC20NotChanging(collatToken, address(marketCrvLP), "There were no collat on the marketCrvLP waiting to be staked");
            }
            verifyReceiveERC20(marketCrvLP.cvxRewardToken(), address(marketCrvLP), collatMarketBalance + lpDeposited, "Collat is received by the staking contract");
        } else {
            feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveERC20(collatToken, address(marketCrvLP), lpDeposited, "Collat is received by the marketCrvLP");
        }
    }

    function _afterDepositCheck(
        address _for,
        uint256 lpDeposited,
        bool isStaked,
        uint256 totalCollateralBefore,
        uint256 balanceCollateralBefore,
        uint256 socFeePending,
        uint256 feeToTake
    ) internal {
        if (isStaked) {
            uint256 collatIncrease = lpDeposited + socFeePending;
            assertEq(0, marketCrvLP.socFeePending(), "When staked, fee pending are deleted");
            assertEq(collatIncrease, marketCrvLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by taking into account the pending sociabilization fee");
            assertEq(collatIncrease, marketCrvLP.collateralBalances(_for) - balanceCollateralBefore, "Collateral of the user is increased by taking into account pending soc fee");
        } else {
            uint256 collatIncrease = lpDeposited - feeToTake;

            assertEq(marketCrvLP.socFeePending(), socFeePending + feeToTake, "Fee pending is equal to the sum of previous fee pending and the new soc fee to take");
            assertEq(collatIncrease, marketCrvLP.totalCollateral() - totalCollateralBefore, "Total collateral is increased by removing the soc fee from the input amount");
            assertEq(
                collatIncrease,
                marketCrvLP.collateralBalances(_for) - balanceCollateralBefore,
                "Collateral of the user is increased by removing the soc fee from the input amount"
            );
        }
    }
}

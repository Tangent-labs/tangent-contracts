// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";

contract HDepositConvexFxnLP is HMarketBase {
    ConvexFxnLPMarket marketFxnLP;
    constructor(address _sender, ConvexFxnLPMarket _market) HandlerBase(_sender, _market) {
        marketFxnLP = ConvexFxnLPMarket(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(
            _for,
            lpDeposited,
            isStaked
        );

        marketFxnLP.deposit(_for, lpDeposited, isStaked);

        _afterDepositCheck(_for, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isStaked) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(
            sender,
            lpDeposited,
            isStaked
        );
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, ) = _beforBorrowOrRepayCheck(marketFxnLP);
        _beforeBorrowCheck(marketFxnLP, sender, borrowedAmount);

        marketFxnLP.depositAndBorrow(lpDeposited, borrowedAmount, isStaked);

        _afterDepositCheck(sender, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
        _afterBorrowCheck(marketFxnLP, borrowedAmount, lastDebt, interests, newDebtIndex, positionDebt);
    }

    function _beforeDepositCheck(
        address _for,
        uint256 lpDeposited,
        bool isStaked
    ) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) {
        IERC20 collatToken = marketFxnLP.collatToken();
        uint256 socFeePercentage = marketFxnLP.socFeePercentage();
        socFeePending = marketFxnLP.socFeePending();

        collatToken.approve(address(marketFxnLP), MAX_UINT);

        totalCollateralBefore = marketFxnLP.totalCollateral();
        balanceCollateralBefore = marketFxnLP.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");
        if (isStaked) {
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
        } else {
            feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveERC20(collatToken, address(marketFxnLP), lpDeposited, "Collat is received by the marketFxnLP");
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
    ) internal view {
        if (isStaked) {
            uint256 collatIncrease = lpDeposited + socFeePending;
            assertEq(0, marketFxnLP.socFeePending(), "When staked, fee pending are deleted");
            assertEq(
                collatIncrease,
                marketFxnLP.totalCollateral() - totalCollateralBefore,
                "Total collateral is increased by taking into account the pending sociabilization fee"
            );
            assertEq(
                collatIncrease,
                marketFxnLP.collateralBalances(_for) - balanceCollateralBefore,
                "Collateral of the user is increased by taking into account pending soc fee"
            );
        } else {
            uint256 collatIncrease = lpDeposited - feeToTake;

            assertEq(
                marketFxnLP.socFeePending(),
                socFeePending + feeToTake,
                "Fee pending is equal to the sum of previous fee pending and the new soc fee to take"
            );
            assertEq(
                collatIncrease,
                marketFxnLP.totalCollateral() - totalCollateralBefore,
                "Total collateral is increased by removing the soc fee from the input amount"
            );
            assertEq(
                collatIncrease,
                marketFxnLP.collateralBalances(_for) - balanceCollateralBefore,
                "Collateral of the user is increased by removing the soc fee from the input amount"
            );
        }
    }
}

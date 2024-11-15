// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../Base/HMarketBase.sol";

contract HDepositConvexCrvLP is HMarketBase {
    constructor(address _sender, ConvexCrvLPMarket _market) HandlerBase(_sender, _market) {}
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(
            _for,
            lpDeposited,
            isStaked
        );

        market.deposit(_for, lpDeposited, isStaked);

        _afterDepositCheck(_for, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isStaked) external handler {
        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeDepositCheck(
            sender,
            lpDeposited,
            isStaked
        );
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, ) = _beforBorrowOrRepayCheck(market);
        _beforeBorrowCheck(market, sender, borrowedAmount);

        market.depositAndBorrow(lpDeposited, borrowedAmount, isStaked);

        _afterDepositCheck(sender, lpDeposited, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
        _afterBorrowCheck(market, borrowedAmount, lastDebt, interests, newDebtIndex, positionDebt);
    }

    function _beforeDepositCheck(
        address _for,
        uint256 lpDeposited,
        bool isStaked
    ) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) {
        IERC20 collatToken = market.collatToken();
        uint256 socFeePercentage = market.socFeePercentage();
        socFeePending = market.socFeePending();

        collatToken.approve(address(market), MAX_UINT);

        totalCollateralBefore = market.totalCollateral();
        balanceCollateralBefore = market.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");
        if (isStaked) {
            uint256 collatMarketBalance = collatToken.balanceOf(address(market));
            if (socFeePending != 0) {
                verifyLostERC20(collatToken, address(market), collatMarketBalance, "Collat in pending is staked by the market");
            } else {
                verifyBalERC20NotChanging(collatToken, address(market), "There were no collat on the market waiting to be staked");
            }
            verifyReceiveERC20(market.cvxRewardToken(), address(market), collatMarketBalance + lpDeposited, "Collat is received by the staking contract");
        } else {
            feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveERC20(collatToken, address(market), lpDeposited, "Collat is received by the market");
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
            assertEq(0, market.socFeePending(), "When staked, fee pending are deleted");
            assertEq(
                collatIncrease,
                market.totalCollateral() - totalCollateralBefore,
                "Total collateral is increased by taking into account the pending sociabilization fee"
            );
            assertEq(
                collatIncrease,
                market.collateralBalances(_for) - balanceCollateralBefore,
                "Collateral of the user is increased by taking into account pending soc fee"
            );
        } else {
            uint256 collatIncrease = lpDeposited - feeToTake;

            assertEq(market.socFeePending(), socFeePending + feeToTake, "Fee pending is equal to the sum of previous fee pending and the new soc fee to take");
            assertEq(
                collatIncrease,
                market.totalCollateral() - totalCollateralBefore,
                "Total collateral is increased by removing the soc fee from the input amount"
            );
            assertEq(
                collatIncrease,
                market.collateralBalances(_for) - balanceCollateralBefore,
                "Collateral of the user is increased by removing the soc fee from the input amount"
            );
        }
    }
}

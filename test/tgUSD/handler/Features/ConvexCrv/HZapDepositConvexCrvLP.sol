// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "./HDepositConvexCrvLP.sol";

import "../../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../../../utils/OdosUtils.sol";

contract HZapDepositConvexCrvLP is HDepositConvexCrvLP {
    Zapper public zapper;
    OdosUtils public odosUtils;

    constructor(address _sender, ConvexCrvLPMarket _market, Zapper _zapper, OdosUtils _odosUtils) HDepositConvexCrvLP(_sender, _market) {
        zapper = _zapper;
        odosUtils = _odosUtils;
    }

    function zapDeposit(Zapper.ZapMarket calldata zapMarket, bytes calldata odosDataCall, bool isStaked) external payable handler {
        uint256 quote = odosUtils.getQuoteOdos(zapMarket.amountIn, zapMarket.tokenIn, marketCrvLP.collatToken(), address(marketCrvLP));

        (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) = _beforeZapDepositCheck(
            zapMarket._for,
            zapMarket.tokenIn,
            zapMarket.amountIn,
            quote,
            isStaked
        );

        zapper.zapDeposit{value: msg.value}(zapMarket, odosDataCall, isStaked);

        _afterZapDepositCheck(zapMarket._for, quote, isStaked, totalCollateralBefore, balanceCollateralBefore, socFeePending, feeToTake);
    }

    function _beforeZapDepositCheck(
        address _for,
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lpDeposited,
        bool isStaked
    ) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore, uint256 socFeePending, uint256 feeToTake) {
        IERC20 collatToken = marketCrvLP.collatToken();

        uint256 socFeePercentage = marketCrvLP.socFeePercentage();
        socFeePending = marketCrvLP.socFeePending();
        if (msg.value != 0) {
            deal(sender, msg.value);
        } else {
            tokenIn.approve(address(zapper), MAX_UINT);
            deal(address(tokenIn), sender, amountIn);
        }

        totalCollateralBefore = marketCrvLP.totalCollateral();
        balanceCollateralBefore = marketCrvLP.collateralBalances(_for);

        verifyLostERC20(tokenIn, sender, amountIn, "Zapped token is deposited by sender");
        if (isStaked) {
            uint256 collatMarketBalance = collatToken.balanceOf(address(marketCrvLP));
            if (socFeePending != 0) {
                verifyLostERC20(collatToken, address(marketCrvLP), collatMarketBalance, "Collat in pending is staked by the marketCrvLP");
            } else {
                verifyBalERC20NotChanging(
                    collatToken,
                    address(marketCrvLP),
                    "There were no collat on the marketCrvLP waiting to be staked so the balance of the market doesn't change"
                );
            }
            verifyReceiveDeltaRelERC20(
                marketCrvLP.cvxRewardToken(),
                address(marketCrvLP),
                collatMarketBalance + lpDeposited,
                1e17,
                "Sum of collat deposited + the pending is received by the staking contract because we are on stake mode"
            );
        } else {
            feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveDeltaRelERC20(collatToken, address(marketCrvLP), lpDeposited, 1e17, "Collat is received by the marketCrvLP");
        }
    }

    function _afterZapDepositCheck(
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
            assertEq(0, marketCrvLP.socFeePending(), "When staked, fee pending are deleted");
            assertApproxEqRel(
                collatIncrease,
                marketCrvLP.totalCollateral() - totalCollateralBefore,
                1e17,
                "Total collateral is increased by taking into account the pending sociabilization fee"
            );
            assertApproxEqRel(
                collatIncrease,
                marketCrvLP.collateralBalances(_for) - balanceCollateralBefore,
                1e17,
                "Collateral of the user is increased by taking into account pending soc fee"
            );
        } else {
            uint256 collatIncrease = lpDeposited - feeToTake;

            assertApproxEqRel(
                marketCrvLP.socFeePending(),
                socFeePending + feeToTake,
                1e17,
                "Fee pending is equal to the sum of previous fee pending and the new soc fee to take"
            );
            assertApproxEqRel(
                collatIncrease,
                marketCrvLP.totalCollateral() - totalCollateralBefore,
                1e17,
                "Total collateral is increased by removing the soc fee from the input amount"
            );
            assertApproxEqRel(
                collatIncrease,
                marketCrvLP.collateralBalances(_for) - balanceCollateralBefore,
                1e17,
                "Collateral of the user is increased by removing the soc fee from the input amount"
            );
        }
    }
}

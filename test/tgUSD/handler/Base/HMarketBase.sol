// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "./HandlerBase.sol";

import {IIRCalculator, IRCheckpoint} from "../../../../src/interfaces/internals/tgUSD/IIRCalculator.sol";

abstract contract HMarketBase is HandlerBase {
    function _beforBorrowOrRepayCheck(
        MarketCore _market
    ) internal view returns (uint256 totalDebtShares, uint256 newInterests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests, uint256 oldTotalDebt) {
        IIRCalculator irCalculator = _market.irCalculator();
        mintableInterests = irCalculator.mintableInterests();
        positionDebt = _market.positionDebt(sender);

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(_market));

        uint256 timeDelta = block.timestamp - timestamp;
        totalDebtShares = _market.totalDebtShares();
        oldTotalDebt = (irCalculator.debtIndexes(address(market)) * totalDebtShares) / RAY;
        uint256 increaseCoeff;
        if (timeDelta == 0) {
            increaseCoeff = 0;
            newInterests = 0;
            newDebtIndex = irCalculator.debtIndexes(address(market));
        } else {
            increaseCoeff = (ir * timeDelta) / 365 days;
            newInterests = (increaseCoeff * oldTotalDebt) / RAY;
            newDebtIndex = irCalculator.debtIndexes(address(market)) + increaseCoeff;
        }
    }

    function _afterCheckpointGlobal(MarketCore _market, uint256 interests, uint256 newDebtIndex, uint256 mintableInterests) internal view {
        IIRCalculator irCalculator = _market.irCalculator();

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(_market));

        assertEq(irCalculator.debtIndexes(address(market)), newDebtIndex, "New total debt index incremented");
        assertEq(irCalculator.mintableInterests(), mintableInterests + interests, "New interests increments mintableInterests");
        assertEq(timestamp, block.timestamp, "Last block IR changed has been updated");
    }

    function _beforeBorrowCheck(MarketCore _market, address receiver, uint256 borrowedAmount) internal {
        verifyMintERC20(_market.tgUSD(), borrowedAmount, "tgUSD are  minted");
        verifyReceiveERC20(_market.tgUSD(), receiver, borrowedAmount, "tgUSD borrowed is received by receiver");
    }

    function _afterBorrowCheck(
        MarketCore _market,
        uint256 borrowedAmount,
        uint256 totalDebtShares,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 positionDebt,
        uint256 oldTotalDebt
    ) internal view {
        assertApproxEqAbs(
            borrowedAmount + interests,
            (_market.totalDebtShares() * _market.irCalculator().debtIndexes(address(_market))) / RAY - oldTotalDebt,
            1,
            "Total debt added is equal to borrowed amount + the interests sasa"
        );
        assertEq(_market.userDebtShares(sender), ((positionDebt + borrowedAmount) * RAY) / newDebtIndex, "New position debt index updated");
    }

    function _beforeRepayCheck(MarketCore _market, uint256 repayedAmount) internal {
        verifyLostERC20(_market.tgUSD(), sender, repayedAmount, "tgUSD repayed is burnt from sender");
        verifyBurnERC20(_market.tgUSD(), repayedAmount, "tgUSD repayed is burnt");
    }

    function _afterRepayCheck(
        MarketCore _market,
        address account,
        uint256 repayedAmount,
        uint256 oldTotalDebt,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 positionDebt
    ) internal view {
        //TODO Check this assert
        // assertApproxEqAbs(oldTotalDebt + interests - (_market.totalDebtShares() * newDebtIndex) / RAY, repayedAmount, 1, "Total new debt didn't decrease");
        assertApproxEqAbs(_market.userDebtShares(account), ((positionDebt - repayedAmount) * RAY) / newDebtIndex, 2, "New position debt index updated");
    }
}

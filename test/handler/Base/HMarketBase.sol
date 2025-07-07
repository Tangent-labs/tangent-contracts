// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "./HandlerBase.sol";

import {IIRCalculator, IRCheckpoint} from "../../../src/interfaces/internals/USG/IIRCalculator.sol";

struct DebtData {
    uint216 ir;
    uint40 timestamp;
    uint256 userDebtShares;
    uint256 totalDebtShares;
    uint256 userDebt;
    uint256 totalDebt;
    uint256 debtIndex;
}

abstract contract HMarketBase is HandlerBase {
    function _beforBorrowOrRepayCheck(MarketCore _market) internal view returns (DebtData memory data) {
        IIRCalculator irCalculator = _market.irCalculator();
        uint256 mintableInterests = irCalculator.mintableInterests();

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(_market));

        uint256 totalDebtShares = _market.totalDebtShares();

        uint256 oldDebtIndex = irCalculator.debtIndexes(address(market));

        uint256 timeDelta = block.timestamp - timestamp;
        // uint256 increaseCoeff;
        // if (timeDelta == 0) {
        //     increaseCoeff = 0;
        //     newInterests = 0;
        //     newDebtIndex = irCalculator.debtIndexes(address(market));
        // } else {
        //     increaseCoeff = (ir * timeDelta) / 365 days;
        //     newInterests = (increaseCoeff * oldTotalDebt) / RAY;
        //     newDebtIndex = irCalculator.debtIndexes(address(market)) + increaseCoeff;
        // }

        return
            DebtData({
                ir: ir,
                timestamp: timestamp,
                userDebtShares: _market.userDebtShares(sender),
                totalDebtShares: totalDebtShares,
                userDebt: _market.userDebt(sender),
                totalDebt: _market.totalDebt(),
                debtIndex: oldDebtIndex
            });
    }

    function _afterCheckpointGlobal(MarketCore _market, uint256 interests, uint256 newDebtIndex, uint256 mintableInterests) internal view {
        IIRCalculator irCalculator = _market.irCalculator();

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(_market));

        assertEq(irCalculator.debtIndexes(address(market)), newDebtIndex, "New total debt index incremented");
        assertEq(irCalculator.mintableInterests(), mintableInterests + interests, "New interests increments mintableInterests");
        assertEq(timestamp, block.timestamp, "Last block IR changed has been updated");
    }

    function _beforeBorrowCheck(MarketCore _market, address receiver, uint256 borrowedAmount) internal {
        verifyMintERC20(_market.USG(), borrowedAmount, "USG are  minted");
        verifyReceiveERC20(_market.USG(), receiver, borrowedAmount, "USG borrowed is received by receiver");
    }

    // function _afterBorrowCheck(
    //     MarketCore _market,
    //     uint256 borrowedAmount,
    //     uint256 newDebtIndex,
    //     uint256 userDebtShares,
    //     uint256 oldTotalDebtShares,
    //     uint256 interests
    // ) internal view {
    //     // assertApproxEqAbs(
    //     //     borrowedAmount + interests,
    //     //     (_market.totalDebtShares() * _market.irCalculator().debtIndexes(address(_market))) / RAY - oldTotalDebtShares,
    //     //     1,
    //     //     "Total debt added is equal to borrowed amount + the interests sasa"
    //     // );
    //     // assertEq(_market.userDebtShares(sender), ((userDebt + borrowedAmount) * RAY) / newDebtIndex, "New position debt index updated");
    // }

    function _beforeRepayCheck(MarketCore _market, uint256 repayedAmount) internal {
        verifyLostERC20(_market.USG(), sender, repayedAmount, "USG repayed is burnt from sender");
        verifyBurnERC20(_market.USG(), repayedAmount, "USG repayed is burnt");
    }

    function _afterRepayCheck(
        MarketCore _market,
        address account,
        uint256 repayedAmount,
        uint256 oldTotalDebt,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 userDebt
    ) internal view {
        //TODO Check this assert
        // assertApproxEqAbs(oldTotalDebt + interests - (_market.totalDebtShares() * newDebtIndex) / RAY, repayedAmount, 1, "Total new debt didn't decrease");
        assertApproxEqAbs(_market.userDebtShares(account), ((userDebt - repayedAmount) * RAY) / newDebtIndex, 2, "New position debt index updated");
    }
}

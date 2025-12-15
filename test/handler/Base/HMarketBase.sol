// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "./HandlerBase.sol";

import {IIRCalculator, IRCheckpoint} from "../../../src/interfaces/internals/USG/IIRCalculator.sol";

struct DebtData {
    uint256 userDebtShares;
    uint256 totalDebtShares;
    uint256 userDebt;
    uint256 totalDebt;
    uint256 oldDebtIndex;
    uint256 newDebtIndex;
    uint256 pendingInterests;
}

abstract contract HMarketBase is HandlerBase {
    function _beforBorrowOrRepayCheck(MarketCore _market) internal view returns (DebtData memory data) {
        IIRCalculator irCalculator = _market.irCalculator();

        return
            DebtData({
                userDebtShares: _market.userDebtShares(sender),
                totalDebtShares: _market.totalDebtShares(),
                userDebt: marketViewer.userDebt(_market, sender),
                totalDebt: marketViewer.totalDebt(_market),
                oldDebtIndex: irCalculator.debtIndexes(address(market)),
                newDebtIndex: irCalculator.newDebtIndex(address(_market)),
                pendingInterests: marketViewer.pendingInterests(_market)
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
        verifyMintERC20(usg, borrowedAmount, "USG are  minted");
        verifyReceiveERC20(usg, receiver, borrowedAmount, "USG borrowed is received by receiver");
    }

    function _afterBorrowCheck(MarketCore _market, uint256 borrowedAmount, uint256 newDebtIndex, uint256 oldUserDebtShares, uint256 oldTotalDebtShares) internal view {
        uint256 newDebtShares = (borrowedAmount * RAY) / newDebtIndex;
        assertApproxEqAbs(_market.userDebtShares(sender), oldUserDebtShares + newDebtShares, 2, "New position debt index updated, borrow");
        assertApproxEqAbs(_market.totalDebtShares(), oldTotalDebtShares + newDebtShares, 2, "New total debt index updated, borrow");
    }

    function _beforeRepayCheck(MarketCore _market, uint256 repaidAmount) internal {
        verifyLostERC20(usg, sender, repaidAmount, "USG repaid is burnt from sender");
        verifyBurnERC20(usg, repaidAmount, "USG repaid is burnt");
    }

    function _afterRepayCheck(
        MarketCore _market,
        address account,
        uint256 repaidAmount,
        uint256 oldTotalDebt,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 userDebt
    ) internal view {
        assertApproxEqAbs(oldTotalDebt + interests - (_market.totalDebtShares() * newDebtIndex) / RAY, repaidAmount, 1, "Total new debt didn't decrease");
        assertApproxEqAbs(_market.userDebtShares(account), ((userDebt - repaidAmount) * RAY) / newDebtIndex, 2, "New position debt index updated");
    }
}

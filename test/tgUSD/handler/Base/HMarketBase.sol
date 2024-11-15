// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "./HandlerBase.sol";

abstract contract HMarketBase is HandlerBase {
    function _beforBorrowOrRepayCheck(
        Market _market
    ) internal view returns (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests) {
        mintableInterests = _market.mintableInterests();
        positionDebt = _market.positionDebt(sender);
        // uint256 positionDebtIndex = market.positionDebtIndex(sender);
        uint256 timeDelta = block.timestamp - _market.blockLastIRTimestamp();
        lastDebt = _market.lastDebt();
        uint256 increaseCoeff;
        if (timeDelta == 0) {
            increaseCoeff = 0;
            interests = 0;
            newDebtIndex = _market.debtIndex();
        } else {
            increaseCoeff = (_market.lastIR() * timeDelta) / 36500 days;
            interests = (increaseCoeff * lastDebt) / RAY;
            newDebtIndex = _market.debtIndex() + increaseCoeff;
        }
    }

    function _beforeBorrowCheck(Market _market, address receiver, uint256 borrowedAmount) internal {
        verifyMintERC20(_market.tgUSD(), borrowedAmount, "tgUSD are  minted");
        verifyReceiveERC20(_market.tgUSD(), receiver, borrowedAmount, "tgUSD borrowed is received by receiver");
    }

    function _afterBorrowCheck(
        Market _market,
        uint256 borrowedAmount,
        uint256 lastDebt,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 positionDebt
    ) internal view {
        assertEq(borrowedAmount + interests, _market.lastDebt() - lastDebt, "Total debt added is equal to borrowed amount + the interests");
        assertEq(_market.positionDebtIndex(sender), ((positionDebt + borrowedAmount) * RAY) / newDebtIndex, "New position debt index updated");
    }

    function _beforeRepayCheck(Market _market, uint256 repayedAmount) internal {
        verifyLostERC20(_market.tgUSD(), sender, repayedAmount, "tgUSD repayed is burnt from sender");
        verifyBurnERC20(_market.tgUSD(), repayedAmount, "tgUSD repayed is burnt");
    }

    function _afterCheckpointGlobal(Market _market, uint256 interests, uint256 newDebtIndex, uint256 mintableInterests) internal view {
        assertEq(_market.debtIndex(), newDebtIndex, "New total debt index incremented");
        assertEq(_market.mintableInterests(), mintableInterests + interests, "New interests increments mintableInterests");
        assertEq(_market.blockLastIRTimestamp(), block.timestamp, "Last block IR changed has been updated");
    }

    function _afterRepayCheck(
        Market _market,
        address account,
        uint256 repayedAmount,
        uint256 lastDebt,
        uint256 interests,
        uint256 newDebtIndex,
        uint256 positionDebt
    ) internal view {
        assertEq(lastDebt + interests - _market.lastDebt(), repayedAmount, "Total new debt didn't decrease");
        assertEq(_market.positionDebtIndex(account), ((positionDebt - repayedAmount) * RAY) / newDebtIndex, "New position debt index updated");
    }
}

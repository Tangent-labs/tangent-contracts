// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../../Base/HMarketBase.sol";

contract HBorrow is HMarketBase {
    constructor(address _sender, MarketExternalActions _market, IERC20 _usg, MarketViewer _marketViewer) HandlerBase(_sender, _market, _usg, _marketViewer) {}

    function borrow(address receiver, uint256 borrowedAmount) external handler {
        DebtData memory debtData = _beforBorrowOrRepayCheck(market);

        _beforeBorrowCheck(market, receiver, borrowedAmount);

        market.borrow(receiver, borrowedAmount);

        // _afterCheckpointGlobal(market, newInterests, newDebtIndex, mintableInterests);
        _afterBorrowCheck(market, borrowedAmount, debtData.newDebtIndex, debtData.userDebtShares, debtData.totalDebtShares);
    }
}

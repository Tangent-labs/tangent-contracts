// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../../Base/HMarketBase.sol";

contract HRepay is HMarketBase {
    constructor(address _sender, MarketExternalActions _market) HandlerBase(_sender, _market) {}

    function repay(address account, uint256 repayedAmount) external handler {
        DebtData memory debtData = _beforBorrowOrRepayCheck(market);

        uint256 USGToRepay = repayedAmount;

        _beforeRepayCheck(market, USGToRepay);

        market.repay(account, repayedAmount);

        // _afterCheckpointGlobal(market, interests, newDebtIndex, mintableInterests);
        // _afterRepayCheck(market, account, USGToRepay, oldTotalDebt, interests, newDebtIndex, userDebt);
    }
}

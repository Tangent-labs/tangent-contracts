// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../Base/HMarketBase.sol";

contract HBorrow is HMarketBase {
    constructor(address _sender, MarketExternalActions _market) HandlerBase(_sender, _market) {}

    function borrow(address receiver, uint256 borrowedAmount) external handler {
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests) = _beforBorrowOrRepayCheck(market);

        _beforeBorrowCheck(market, receiver, borrowedAmount);

        market.borrow(receiver, borrowedAmount);

        _afterCheckpointGlobal(market, interests, newDebtIndex, mintableInterests);
        _afterBorrowCheck(market, borrowedAmount, lastDebt, interests, newDebtIndex, positionDebt);
    }

    function repay(address account, uint256 repayedAmount) external handler {
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests) = _beforBorrowOrRepayCheck(market);

        uint256 tgUSDToRepay = repayedAmount;
        if (repayedAmount == MAX_UINT) {
            tgUSDToRepay = positionDebt;
        }

        _beforeRepayCheck(market, tgUSDToRepay);

        market.repay(account, repayedAmount);

        _afterCheckpointGlobal(market, interests, newDebtIndex, mintableInterests);
        _afterRepayCheck(market, account, tgUSDToRepay, lastDebt, interests, newDebtIndex, positionDebt);
    }
}

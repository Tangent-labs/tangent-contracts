// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../../Base/HMarketBase.sol";

contract HBorrow is HMarketBase {
    constructor(address _sender, MarketExternalActions _market) HandlerBase(_sender, _market) {}

    function borrow(address receiver, uint256 borrowedAmount) external handler {
        (uint256 totalDebtShares, uint256 newInterests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests, uint256 oldTotalDebt) = _beforBorrowOrRepayCheck(
            market
        );

        _beforeBorrowCheck(market, receiver, borrowedAmount);

        market.borrow(receiver, borrowedAmount);

        _afterCheckpointGlobal(market, newInterests, newDebtIndex, mintableInterests);
        _afterBorrowCheck(market, borrowedAmount, totalDebtShares, newInterests, newDebtIndex, positionDebt, oldTotalDebt);
    }
}

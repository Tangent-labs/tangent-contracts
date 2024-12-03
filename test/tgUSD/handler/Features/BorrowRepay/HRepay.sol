// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../../Base/HMarketBase.sol";

contract HRepay is HMarketBase {
    constructor(address _sender, MarketExternalActions _market) HandlerBase(_sender, _market) {}

    function repay(address account, uint256 repayedAmount, address callerZapper) external handler {
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, uint256 mintableInterests) = _beforBorrowOrRepayCheck(market);

        uint256 tgUSDToRepay = repayedAmount;
        if (repayedAmount >= positionDebt) {
            tgUSDToRepay = positionDebt;
        }

        _beforeRepayCheck(market, tgUSDToRepay);

        market.repay(account, repayedAmount, callerZapper);

        _afterCheckpointGlobal(market, interests, newDebtIndex, mintableInterests);
        _afterRepayCheck(market, account, tgUSDToRepay, lastDebt, interests, newDebtIndex, positionDebt);
    }
}

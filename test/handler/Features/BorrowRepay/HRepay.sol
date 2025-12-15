// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "../../Base/HMarketBase.sol";

contract HRepay is HMarketBase {
    constructor(address _sender, MarketExternalActions _market, IERC20 _usg, MarketViewer _marketViewer) HandlerBase(_sender, _market, _usg, _marketViewer) {}

    function repay(address account, uint256 repaidAmount) external handler {
        DebtData memory debtData = _beforBorrowOrRepayCheck(market);

        uint256 usgToRepay = repaidAmount > debtData.userDebt ? debtData.userDebt : repaidAmount;

        _beforeRepayCheck(market, usgToRepay);

        market.repay(account, repaidAmount);
        assertERC20Tracking();

        // _afterCheckpointGlobal(market, interests, newDebtIndex, mintableInterests);
        // _afterRepayCheck(market, account, USGToRepay, oldTotalDebt, interests, newDebtIndex, userDebt);
    }
}

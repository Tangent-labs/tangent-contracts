// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetMarketDetails, IMarketViewer, IERC20} from "../GetMarketDetails.sol";

contract MarketDetailsUI is GetMarketDetails {
    error MarketDetailsUIOutError(MarketRow output);

    constructor(address account, address market, IMarketViewer marketViewer, IERC20 usg) {
        revert MarketDetailsUIOutError(getMarketDetails(account, market, marketViewer, usg));
    }
}

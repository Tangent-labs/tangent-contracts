// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetMarketDetails, IMarketViewer} from "../GetMarketDetails.sol";

contract MarketDetailsUI is GetMarketDetails {
    error MarketDetailsUIOutError(MarketRow output);

    constructor(address account, address market, IMarketViewer marketViewer) {
        revert MarketDetailsUIOutError(getMarketDetails(account, market, marketViewer));
    }
}

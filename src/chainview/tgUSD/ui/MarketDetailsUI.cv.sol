// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {GetMarketDetails} from "../GetMarketDetails.sol";

contract MarketDetailsUI is GetMarketDetails {
    error MarketDetailsUIOutError(MarketRow output);

    constructor(address account, address market) {
        revert MarketDetailsUIOutError(getMarketDetails(account, market));
    }
}

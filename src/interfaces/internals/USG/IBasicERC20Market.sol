// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GlobalMarketInitParams, MarketInit} from "./IMarketCore.sol";
interface IBasicERC20Market {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit) external;
}

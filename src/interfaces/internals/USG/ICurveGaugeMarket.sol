// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GlobalMarketInitParams, MarketInit} from "./IMarketCore.sol";
import {IGauge} from "../../externals/Curve/IGauge.sol";
interface ICurveGaugeMarket {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, IGauge _gauge) external;
}

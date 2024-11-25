// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "./IPriceOracle.sol";
import {ItgUSD} from "./ItgUSD.sol";
import {ICollateral, IERC20Metadata} from "./ICollateral.sol";
import {IControlTower} from "./IControlTower.sol";
interface IMarketCore {
    struct MarketInit {
        ItgUSD tgUSD;
        IControlTower controlTower;
        IPriceOracle tgUSDOracle;
        IERC20Metadata collatToken;
        IPriceOracle collatOracle;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 maxMarketDebt;
        uint256 minimumLoan;
    }
}

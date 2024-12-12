// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIrCalculator} from "./IIrCalculator.sol";
import {ITgUSD} from "./ITgUSD.sol";
import {ICollateral, IERC20Metadata} from "./ICollateral.sol";
import {IControlTower} from "./IControlTower.sol";
import {IPriceOracle} from "./IPriceOracle.sol";

interface IMarketCore {
    struct MarketInit {
        ITgUSD tgUSD;
        IControlTower controlTower;
        IIrCalculator irCalculator;
        IERC20Metadata collatToken;
        IPriceOracle collatOracle;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 maxMarketDebt;
        uint256 minimumLoan;
    }
}

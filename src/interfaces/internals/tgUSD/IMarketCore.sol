// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIRCalculator} from "./IIRCalculator.sol";
import {ITgUSD} from "./ITgUSD.sol";
import {ICollateral, IERC20Metadata} from "./ICollateral.sol";
import {IControlTower} from "./IControlTower.sol";
import {IPriceOracle} from "./IPriceOracle.sol";
import {ILiquidatorProxy} from "./ILiquidatorProxy.sol";
import {IRewardAccumulator} from "./IRewardAccumulator.sol";

interface IMarketCore {
    struct MarketConstants {
        address _owner;
        ITgUSD _tgUSD;
        IControlTower _controlTower;
        IIRCalculator _irCalculator;
        IRewardAccumulator _rewardAccumulator;
        ILiquidatorProxy _liquidatorProxy;
    }

    struct MarketInit {
        IERC20Metadata collatToken;
        IPriceOracle collatOracle;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 maxMarketDebt;
        uint256 minimumLoan;
        IERC20Metadata[] _rewardTokens;
    }
}

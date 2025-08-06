// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZapStruct} from "../ICommonStruct.sol";
import {IIRCalculator} from "./IIRCalculator.sol";
import {IUSG} from "./IUSG.sol";
import {ICollateral, IERC20Metadata} from "./ICollateral.sol";
import {IControlTower} from "./IControlTower.sol";
import {IPriceOracle} from "./IPriceOracle.sol";
import {IZappingProxy} from "./IZappingProxy.sol";
import {IRewardAccumulator} from "./IRewardAccumulator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct LiquidateInput {
    address account;
    uint256 collatToLiquidate;
    uint256 minUSGOut;
    uint256 newDebtIndex;
    uint256 _collateralBalance;
    uint256 _totalCollateral;
    uint256 _userDebtShares;
    uint256 _totalDebtShares;
    uint256 userDebt;
}

struct SelfLiquidateInput {
    uint256 collatAmountToLiquidate;
    uint256 USGToRepay;
    uint256 minUSGOut;
    uint256 newDebtIndex;
    uint256 _collateralBalance;
    uint256 _totalCollateral;
    uint256 _userDebtShares;
    uint256 _totalDebtShares;
    uint256 userDebt;
}

struct GlobalMarketInitParams {
    address _owner;
    IUSG _USG;
    IControlTower _controlTower;
    IIRCalculator _irCalculator;
    IRewardAccumulator _rewardAccumulator;
    IZappingProxy _zappingProxy;
}

struct MarketInit {
    IERC20Metadata collatToken;
    IPriceOracle collatOracle;
    uint256 maxLTV;
    uint256 liquidationThreshold;
    uint256 liquidationFee;
    uint256 maxMarketDebt;
    uint256 minimumLoan;
    string name;
}

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

struct LiquidationPre {
    uint256 newDebtIndex;
    uint256 collatBalance;
    uint256 _userDebtShares;
    uint256 userDebt_;
}

struct LiquidateIn {
    address account;
    PostLiquidate postLiquidate;
    uint256 minCollatValueToLiquidate;
}

struct LiquidateTransitionStruct {
    LiquidateIn liquidateIn;
    uint256 collatPrice;
    uint256 newDebtIndex;
    uint256 _collateralBalance;
    uint256 _totalCollateral;
    uint256 _userDebtShares;
    uint256 _totalDebtShares;
    uint256 userDebt;
}

struct PostLiquidate {
    uint256 collatAmountToLiquidate;
    uint256 minUsgOut;
    uint256 maxUsgToBurn;
    uint256 minCollatAmountToLiquidate;
    bool isReceiptOut;
}

struct SelfLiquidateIn {
    uint256 collatAmountToLiquidate;
    uint256 usgToRepay;
    uint256 maxUsgToBurn;
    uint256 minUsgOut;
    bool isReceiptOut;
}

struct SelfLiquidateTransitionStruct {
    SelfLiquidateIn selfLiquidateIn;
    uint256 newDebtIndex;
    uint256 _collateralBalance;
    uint256 _totalCollateral;
    uint256 _userDebtShares;
    uint256 _totalDebtShares;
    uint256 userDebt;
}

struct LeverageIn {
    uint256 collatToDeposit;
    uint256 usgToFlashMint;
    uint256 minCollatAmountOut;
    bool isReceiptIn;
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
    IERC20[] rewardTokens;
    string name;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";
import {IMarketExternalActions, IERC20, IERC20Metadata} from "../../../interfaces/internals/USG/IMarketExternalActions.sol";
import {ICollateral, IPriceOracle} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../../interfaces/internals/USG/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket, IStakingProxyERC20} from "../../../interfaces/internals/USG/IConvexFxnLPMarket.sol";
import {IWStable} from "../../../interfaces/internals/USG/IWStable.sol";

import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

import {IVirtualBalanceRewardPool} from "../../../interfaces/externals/Convex/IVirtualBalanceRewardPool.sol";
import {ISharedLiquidityGauge} from "../../../interfaces/externals/FXN/ISharedLiquidityGauge.sol";

import {IStashTokenWrapper} from "../../../interfaces/externals/Convex/IStashTokenWrapper.sol";
import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IPegKeeperV2} from "../../../interfaces/externals/LlamaLend/IPegKeeperV2.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {IMarketViewer} from "../../../interfaces/internals/USG/IMarketViewer.sol";

import {UsgInfo, USGInfoOut, IERC4626} from "../../UsgInfo.sol";

struct USGContractsIn {
    IRewardAccumulator rewardAccumulator;
    IIRCalculator irCalculator;
    IERC20 usg;
    IERC4626 sUSG;
    IAggregatorStablePriceV3 usgOracle;
    IMarketViewer _marketViewer;
}
struct MarketAPRInput {
    address marketAddress;
    uint256 aprComputationType;
}
struct USGIndexingGlobalDataOut {
    uint256 timestamp;
    TVLAprs[] marketData;
    USGInfoOut usgInfo;
    KeeperData[] keepersData;
    WStableData[] wStablesData;
}
struct TVLAprs {
    GlobalData globalData;
    StreamingData[] currentAPR;
    TVLStreamingData projectedAPR;
}

struct GlobalData {
    address marketAddress;
    uint256 totalStakedAmount;
    uint256 totalStakedUSD;
    uint256 totalDebt;
    uint256 badDebt;
    uint256 oraclePrice;
    uint256 irApr;
    uint256 rewardCut;
    IERC20[] rewardTokens;
}
struct StreamingData {
    IERC20 token;
    uint256 amountPerYear;
}
struct TVLStreamingData {
    uint256 totalSupplyUnderlying;
    StreamingData[] streamingData;
}

struct KeeperData {
    address keeper;
    address lp;
    uint256 lpBalance;
    uint256 virtualPrice;
    address coin0;
    address coin1;
}

struct WStableData {
    address wStable;
    address stable;
    uint256 totalSupply;
}
struct KeeperIn {
    address keeper;
    address lp;
}
interface IDistributedToken {
    function rate() external view returns (uint256);
}

contract USGIndexingGlobalData is UsgInfo {
    uint256 constant ONE_YEAR = 365 days;
    error MarketCurrentAPRError(USGIndexingGlobalDataOut);

    constructor(MarketAPRInput[] memory markets, USGContractsIn memory contracts, KeeperIn[] memory keepersIn, address[] memory wStables) {
        address[] memory keepers = new address[](keepersIn.length);
        for (uint256 i; i < keepersIn.length; i++) {
            keepers[i] = keepersIn[i].keeper;
        }
        revert MarketCurrentAPRError(
            USGIndexingGlobalDataOut({
                timestamp: block.timestamp,
                marketData: getMarketsData(markets, contracts.rewardAccumulator, contracts.irCalculator, contracts._marketViewer),
                usgInfo: getUSGInfo(contracts.usg, contracts.sUSG, keepers, contracts.usgOracle),
                keepersData: getPegKeepersData(keepersIn),
                wStablesData: getWrappedStablesData(wStables)
            })
        );
    }

    function getPegKeepersData(KeeperIn[] memory keepersIn) internal view returns (KeeperData[] memory) {
        uint256 keepersLen = keepersIn.length;
        KeeperData[] memory keepersData = new KeeperData[](keepersLen);
        for (uint256 i; i < keepersLen; i++) {
            address pegKeeper = keepersIn[i].keeper;
            ICurveStableSwapNG lp = ICurveStableSwapNG(keepersIn[i].lp);
            keepersData[i] = KeeperData({
                keeper: pegKeeper,
                lp: address(lp),
                lpBalance: lp.balanceOf(pegKeeper),
                virtualPrice: lp.get_virtual_price(),
                coin0: lp.coins(0),
                coin1: lp.coins(1)
            });
        }
        return keepersData;
    }

    function getWrappedStablesData(address[] memory wStables) internal view returns (WStableData[] memory) {
        uint256 wStablesLen = wStables.length;
        WStableData[] memory wStablesData = new WStableData[](wStablesLen);
        for (uint256 i; i < wStablesLen; i++) {
            IWStable wStable = IWStable(wStables[i]);
            wStablesData[i] = WStableData({wStable: address(wStable), stable: wStable.stable(), totalSupply: wStable.totalSupply()});
        }
        return wStablesData;
    }

    function getMarketsData(
        MarketAPRInput[] memory markets,
        IRewardAccumulator rewardAccumulator,
        IIRCalculator irCalculator,
        IMarketViewer _marketViewer
    ) public view returns (TVLAprs[] memory) {
        TVLAprs[] memory output = new TVLAprs[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i].marketAddress;
            GlobalData memory globalData = _getMarketData(market, rewardAccumulator, irCalculator, _marketViewer);
            output[i] = TVLAprs({
                globalData: globalData,
                currentAPR: _getCurrentAPR(market, globalData.rewardTokens, rewardAccumulator),
                projectedAPR: _getProjectedAPR(market, markets[i].aprComputationType)
            });
        }
        return output;
    }

    function _getMarketData(
        address market,
        IRewardAccumulator rewardAccumulator,
        IIRCalculator irCalculator,
        IMarketViewer _marketViewer
    ) internal view returns (GlobalData memory) {
        uint256 totalStakedAmount = ICollateral(market).totalCollateral();
        IPriceOracle oracle = ICollateral(market).collatOracle();
        uint256 oraclePrice = oracle.latestAnswer(true) * 10 ** (18 - oracle.decimals());

        return
            GlobalData({
                marketAddress: market,
                totalStakedAmount: totalStakedAmount,
                totalStakedUSD: (oraclePrice * totalStakedAmount) / 1e18,
                totalDebt: _marketViewer.totalDebt(IDebtIR(market)),
                badDebt: IDebtIR(market).badDebt(),
                oraclePrice: oraclePrice,
                irApr: irCalculator.getIRCheckpoint(market).ir,
                rewardCut: rewardAccumulator.lastRewardCuts(market),
                rewardTokens: rewardAccumulator.getRewardTokens(market)
            });
    }

    function _getCurrentAPR(address market, IERC20[] memory rewardTokens, IRewardAccumulator rewardAccumulator) internal view returns (StreamingData[] memory) {
        StreamingData[] memory aprs = new StreamingData[](rewardTokens.length);
        for (uint256 j; j < rewardTokens.length; j++) {
            IERC20 rewardToken = rewardTokens[j];
            aprs[j] = StreamingData({token: rewardToken, amountPerYear: rewardAccumulator.getRewardData(market, rewardToken).rewardRate * 365 days});
        }
        return aprs;
    }

    function _getProjectedAPR(address market, uint256 aprType) internal view returns (TVLStreamingData memory) {
        // Convex CRV
        if (aprType == 0) {
            return _getProjectedAPRConvexCRV(market);
        }
        // Convex FXN
        else if (aprType == 1) {
            return _getProjectedAPRBlank();
        }
        // PENDLE PT
        else if (aprType == 2) {
            _getProjectedAPRBlank();
        }
    }

    IERC20 constant CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

    function _getProjectedAPRConvexCRV(address market) internal view returns (TVLStreamingData memory) {
        IConvexCrvLPMarket cvxCrvMarket = IConvexCrvLPMarket(market);
        ICvxRewardToken cvxRewardToken = cvxCrvMarket.cvxRewardToken();
        uint256 extraRewardLen = cvxCrvMarket.cvxRewardToken().extraRewardsLength();
        StreamingData[] memory streamData = new StreamingData[](extraRewardLen + 1);

        streamData[0] = StreamingData({token: CRV, amountPerYear: cvxRewardToken.periodFinish() < block.timestamp ? 0 : cvxRewardToken.rewardRate() * ONE_YEAR});
        for (uint256 i; i < extraRewardLen; i++) {
            IVirtualBalanceRewardPool extraReward = IVirtualBalanceRewardPool(cvxRewardToken.extraRewards(i));
            IStashTokenWrapper stashWrapperToken = IStashTokenWrapper(address(extraReward.rewardToken()));
            IERC20 realRewardToken = IERC20(address(stashWrapperToken));

            try stashWrapperToken.token() {
                realRewardToken = stashWrapperToken.token();
            } catch {}
            streamData[i + 1] = StreamingData({token: realRewardToken, amountPerYear: extraReward.rewardRate() * ONE_YEAR});
        }

        return TVLStreamingData({totalSupplyUnderlying: cvxRewardToken.totalSupply(), streamingData: streamData});
    }

    function _getProjectedAPRBlank() internal pure returns (TVLStreamingData memory) {}
}

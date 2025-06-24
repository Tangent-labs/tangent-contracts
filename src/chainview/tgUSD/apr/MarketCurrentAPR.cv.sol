// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketExternalActions, IERC20} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {ICollateral, IPriceOracle} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../../interfaces/internals/tgUSD/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket, IStakingProxyERC20} from "../../../interfaces/internals/tgUSD/IConvexFxnLPMarket.sol";

import {IVirtualBalanceRewardPool} from "../../../interfaces/externals/Convex/IVirtualBalanceRewardPool.sol";
import {ISharedLiquidityGauge} from "../../../interfaces/externals/FXN/ISharedLiquidityGauge.sol";
import {IGaugeController} from "../../../interfaces/externals/FXN/IGaugeController.sol";

import {IStashTokenWrapper} from "../../../interfaces/externals/Convex/IStashTokenWrapper.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/tgUSD/IIRCalculator.sol";
import "hardhat/console.sol";

struct MarketAPRInput {
    address marketAddress;
    uint256 aprComputationType;
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
interface IDistributedToken {
    function rate() external view returns (uint256);
}
contract MarketCurrentAPR {
    uint256 constant ONE_YEAR = 365 days;
    error MarketCurrentAPRError(TVLAprs[]);

    constructor(MarketAPRInput[] memory markets, IRewardAccumulator rewardAccumulator, IIRCalculator irCalculator) {
        revert MarketCurrentAPRError(getMarketTVLAPRs(markets, rewardAccumulator, irCalculator));
    }

    function getMarketTVLAPRs(MarketAPRInput[] memory markets, IRewardAccumulator rewardAccumulator, IIRCalculator irCalculator) public view returns (TVLAprs[] memory) {
        TVLAprs[] memory output = new TVLAprs[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i].marketAddress;
            GlobalData memory globalData = _getGlobalData(market, rewardAccumulator, irCalculator);

            output[i] = TVLAprs({
                globalData: globalData,
                currentAPR: _getCurrentAPR(market, globalData.rewardTokens, rewardAccumulator),
                projectedAPR: _getProjectedAPR(market, markets[i].aprComputationType)
            });
        }
        return output;
    }

    function _getGlobalData(address market, IRewardAccumulator rewardAccumulator, IIRCalculator irCalculator) internal view returns (GlobalData memory) {
        uint256 totalStakedAmount = ICollateral(market).totalCollateral();
        IPriceOracle oracle = ICollateral(market).collatOracle();
        uint256 oraclePrice = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());

        return
            GlobalData({
                marketAddress: market,
                totalStakedAmount: totalStakedAmount,
                totalStakedUSD: (oraclePrice * totalStakedAmount) / 1e18,
                totalDebt: IDebtIR(market).totalDebt(),
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

    function _getProjectedAPRBlank() internal view returns (TVLStreamingData memory) {
        return TVLStreamingData({totalSupplyUnderlying: 0, streamingData: new StreamingData[](0)});
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketExternalActions, IERC20} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {ICollateral, IPriceOracle} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";

struct MarketAPRInput {
    address marketAddress;
    uint256 aprComputationType;
}
struct APR {
    IERC20 token;
    uint256 amountPerYear;
}
struct TVLAprs {
    uint256 totalStakedAmount;
    uint256 totalStakedUSD;
    uint256 totalDebt;
    uint256 badDebt;
    APR[] aprs;
}
contract MarketCurrentAPR {
    error MarketCurrentAPRError(TVLAprs[]);

    constructor(MarketAPRInput[] memory markets, IRewardAccumulator rewardAccumulator) {
        revert MarketCurrentAPRError(getMarketTVLAPRs(markets, rewardAccumulator));
    }

    function getMarketTVLAPRs(MarketAPRInput[] memory markets, IRewardAccumulator rewardAccumulator) public view returns (TVLAprs[] memory) {
        TVLAprs[] memory output = new TVLAprs[](markets.length);

        IRewardAccumulator _rewardAcc = rewardAccumulator;

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i].marketAddress;
            uint256 totalStakedAmount = ICollateral(market).totalCollateral();
            IPriceOracle oracle = ICollateral(market).collatOracle();
            uint256 totalStakedUSD = ((oracle.latestAnswer() * totalStakedAmount) * 10 ** (18 - oracle.decimals())) / 1e18;

            IERC20[] memory rewardTokens = _rewardAcc.getRewardTokens(market);
            APR[] memory aprs = new APR[](rewardTokens.length);
            for (uint256 j; j < rewardTokens.length; j++) {
                aprs[j] = APR({token: rewardTokens[j], amountPerYear: _rewardAcc.getRewardData(market, rewardTokens[j]).rewardRate * 365 days});
            }

            output[i] = TVLAprs({
                totalStakedAmount: totalStakedAmount,
                totalStakedUSD: totalStakedUSD,
                totalDebt: IDebtIR(market).totalDebt(),
                badDebt: IDebtIR(market).badDebt(),
                aprs: aprs
            });
        }
        return output;
    }
}

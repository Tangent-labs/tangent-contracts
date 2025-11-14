// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IPegKeeperV2} from "../../../interfaces/externals/LlamaLend/IPegKeeperV2.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";

contract OnchainTxBot {
    struct IRAndRC {
        uint256 lastIR;
        uint256 newIR;
        uint256 lastRC;
        uint256 newRC;
    }
    error OnchainTxBotError(uint256[] profits, IRAndRC[] irsAndRcs);

    constructor(IPegKeeperV2[] memory pegKeepers, IDebtIR[] memory markets) {
        uint256 len = pegKeepers.length;
        uint256[] memory profits = new uint256[](len);

        for (uint256 i; i < len; ) {
            IPegKeeperV2 curveQuote = pegKeepers[i];

            try curveQuote.estimate_caller_profit() returns (uint256 profit) {
                profits[i] = profit;
            } catch {
                profits[i] = 0;
            }
            unchecked {
                ++i;
            }
        }
        len = markets.length;
        IRAndRC[] memory irsAndRcs = new IRAndRC[](len);

        for (uint256 i = 0; i < markets.length; i++) {
            IDebtIR market = markets[i];
            ICollateral marketCollat = ICollateral(address(markets[i]));

            IIRCalculator irCalculator = market.irCalculator();
            IRewardAccumulator rewardAcc = marketCollat.rewardAccumulator();

            (uint216 lastIR, ) = irCalculator.irCheckpoints(address(market));

            irsAndRcs[i] = IRAndRC({
                lastIR: lastIR,
                newIR: irCalculator.computeIRForMarket(address(market)),
                lastRC: rewardAcc.lastRewardCuts(address(market)),
                newRC: rewardAcc.computeRCForMarket(address(market))
            });
        }
        revert OnchainTxBotError(profits, irsAndRcs);
    }
}

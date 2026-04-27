// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {IGauge} from "../../../interfaces/externals/Curve/IGauge.sol";

struct GaugeBoost {
    uint256 pid;
    uint256 boost;
}

struct ConvexBoostsUIOut {
    uint256 fee;
    GaugeBoost[] gaugeBoosts;
}

contract ConvexBoostsUI {
    ICvxBooster private constant BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address private constant VOTER_PROXY = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;

    error ConvexBoostsUIOutError(ConvexBoostsUIOut output);

    constructor(uint256[] memory pids) {
        uint256 fee = (BOOSTER.lockIncentive() + BOOSTER.stakerIncentive() + BOOSTER.earmarkIncentive() + BOOSTER.platformFee()) * 1e18 / 10000;

        uint256 len = pids.length;
        GaugeBoost[] memory gaugeBoosts = new GaugeBoost[](len);

        for (uint256 i; i < len; ) {
            (, , address gaugeAddr, , , ) = BOOSTER.poolInfo(pids[i]);
            IGauge gauge = IGauge(gaugeAddr);
            uint256 boost;

            uint256 balance = gauge.balanceOf(VOTER_PROXY);
            if (balance != 0) {
                uint256 working = gauge.working_balances(VOTER_PROXY);
                // boost = working / (balance * 0.4), expressed with 1e18 precision
                boost = (working * 10 * 1e18) / (balance * 4);
            }

            gaugeBoosts[i] = GaugeBoost({pid: pids[i], boost: boost});

            unchecked {
                ++i;
            }
        }

        revert ConvexBoostsUIOutError(ConvexBoostsUIOut({fee: fee, gaugeBoosts: gaugeBoosts}));
    }
}
